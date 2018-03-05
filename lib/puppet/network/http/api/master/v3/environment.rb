require 'puppet/util/json'
require 'puppet/parser/environment_compiler'

class Puppet::Network::HTTP::API::Master::V3::Environment
  def call(request, response)
    env_name = request.routing_path.split('/').last
    env = Puppet.lookup(:environments).get(env_name)
    code_id = request.params[:code_id]

    if env.nil?
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new(_("%{env_name} is not a known environment") % { env_name: env_name }, Puppet::Network::HTTP::Issues::RESOURCE_NOT_FOUND)
    end

    catalog = Puppet::Parser::EnvironmentCompiler.compile(env, code_id).to_resource

    env_graph = build_environment_graph(catalog)

    response.respond_with(200, "application/json", Puppet::Util::Json.dump(env_graph))
  end

  def build_environment_graph(catalog)
    # This reads catalog and code_id off the catalog rather than using the one
    # from the request. There shouldn't really be a case where the two differ,
    # but if they do, the one from the catalog itself is authoritative.
    env_graph = {:environment => catalog.environment, :applications => {}, :code_id => catalog.code_id}
    applications = catalog.resources.select do |res|
      type = res.resource_type
      type.is_a?(Puppet::Resource::Type) && type.application?
    end
    applications.each do |app|
      file, line = app.file, app.line
      nodes = app['nodes']

      required_components = catalog.direct_dependents_of(app).map {|comp| comp.ref}
      mapped_components = nodes.values.flatten.map {|comp| comp.ref}

      nonexistent_components = mapped_components - required_components
      if nonexistent_components.any?
        raise Puppet::ParseError.new(
            _("Application %{application} assigns nodes to non-existent components: %{component_list}") %
                { application: app, component_list: nonexistent_components.join(', ') }, file, line)
      end

      missing_components = required_components - mapped_components
      if missing_components.any?
        raise Puppet::ParseError.new(_("Application %{application} has components without assigned nodes: %{component_list}") %
                                         { application: app, component_list: missing_components.join(', ') }, file, line)
      end

      # Turn the 'nodes' hash into a map component ref => node name
      node_mapping = {}
      nodes.each do |node, comps|
        comps = [comps] unless comps.is_a?(Array)
        comps.each do |comp|
          raise Puppet::ParseError.new(_("Application %{app} assigns multiple nodes to component %{comp}") % { app: app, comp: comp }, file, line) if node_mapping.include?(comp.ref)
          node_mapping[comp.ref] = node.title
        end
      end

      app_components = {}
      catalog.direct_dependents_of(app).each do |comp|
        app_components[comp.ref] = {
          :produces => comp.export.map(&:ref),
          :consumes => prerequisites(comp).map(&:ref),
          :node => node_mapping[comp.ref]
        }
      end
      env_graph[:applications][app.ref] = app_components
    end

    env_graph
  end

  private

  # Finds all the prerequisites of component +comp+. They are all the
  # capability resources that +comp+ depends on; this includes resources
  # that +comp+ consumes but also resources it merely requires
  def prerequisites(comp)
    params = Puppet::Type.relationship_params.select { |p| p.direction == :in }.map(&:name)
    params.map { |rel| comp[rel] }.flatten.compact.select do |rel|
      rel.resource_type && rel.resource_type.is_capability?
    end
  end
end
