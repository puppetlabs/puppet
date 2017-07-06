require 'json'
require 'puppet/parser/environment_compiler'

class Puppet::Network::HTTP::API::Master::V3::Environment
  def call(request, response)
    env_name = request.routing_path.split('/').last
    env = Puppet.lookup(:environments).get(env_name)
    code_id = request.params[:code_id]

    if env.nil?
      raise Puppet::Network::HTTP::Error::HTTPNotFoundError.new("#{env_name} is not a known environment", Puppet::Network::HTTP::Issues::RESOURCE_NOT_FOUND)
    end

    catalog = Puppet::Parser::EnvironmentCompiler.compile(env, code_id).to_resource

    # This reads code_id off the catalog rather than using the one from the
    # request. There shouldn't really be a case where the two differ, but if
    # they do, the one from the catalog itself is authoritative.
    env_graph = {:environment => env.name, :applications => {}, :code_id => catalog.code_id}
    applications = catalog.resources.select do |res|
      type = res.resource_type
      type.is_a?(Puppet::Resource::Type) && type.application?
    end
    applications.each do |app|
      app_components = {}
      # Turn the 'nodes' hash into a map component ref => node name
      node_mapping = {}
      app['nodes'].each do |node, comps|
        comps = [comps] unless comps.is_a?(Array)
        comps.each do |comp|
          raise Puppet::ParseError, "Application #{app} maps component #{comp} to multiple nodes" if node_mapping.include?(comp.ref)
          node_mapping[comp.ref] = node.title
        end
      end

      catalog.direct_dependents_of(app).each do |comp|
        mapped_node = node_mapping[comp.ref]
        if mapped_node.nil?
          raise Puppet::ParseError, "Component #{comp} is not mapped to any node"
        end
        app_components[comp.ref] = {
          :produces => comp.export.map(&:ref),
          :consumes => prerequisites(comp).map(&:ref),
          :node => mapped_node
        }
      end
      env_graph[:applications][app.ref] = app_components
    end
    response.respond_with(200, "application/json", JSON.dump(env_graph))
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
