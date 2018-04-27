module Puppet::ModuleTool::Shared

  include Puppet::ModuleTool::Errors

  def get_local_constraints
    @local      = Hash.new { |h,k| h[k] = { } }
    @conditions = Hash.new { |h,k| h[k] = [] }
    @installed  = Hash.new { |h,k| h[k] = [] }

    @environment.modules_by_path.values.flatten.each do |mod|
      mod_name = (mod.forge_name || mod.name).gsub('/', '-')
      @installed[mod_name] << mod
      d = @local["#{mod_name}@#{mod.version}"]
      (mod.dependencies || []).each do |hash|
        name, conditions = hash['name'], hash['version_requirement']
        name = name.gsub('/', '-')
        d[name] = conditions
        @conditions[name] << {
          :module => mod_name,
          :version => mod.version,
          :dependency => conditions
        }
      end
    end
  end

  def get_remote_constraints(forge)
    @remote   = Hash.new { |h,k| h[k] = { } }
    @urls     = {}
    @versions = Hash.new { |h,k| h[k] = [] }

    Puppet.notice _("Downloading from %{uri} ...") % { uri: forge.uri }
    author, modname = Puppet::ModuleTool.username_and_modname_from(@module_name)
    info = forge.remote_dependency_info(author, modname, @options[:version])
    info.each do |pair|
      mod_name, releases = pair
      mod_name = mod_name.gsub('/', '-')
      releases.each do |rel|
        semver = SemanticPuppet::Version.parse(rel['version']) rescue SemanticPuppet::Version::MIN
        @versions[mod_name] << { :vstring => rel['version'], :semver => semver }
        @versions[mod_name].sort! { |a, b| a[:semver] <=> b[:semver] }
        @urls["#{mod_name}@#{rel['version']}"] = rel['file']
        d = @remote["#{mod_name}@#{rel['version']}"]
        (rel['dependencies'] || []).each do |name, conditions|
          d[name.gsub('/', '-')] = conditions
        end
      end
    end
  end

  def implicit_version(mod)
    return :latest if @conditions[mod].empty?
    if @conditions[mod].all? { |c| c[:queued] || c[:module] == :you }
      return :latest
    end
    return :best
  end

  def annotated_version(mod, versions)
    if versions.empty?
      return implicit_version(mod)
    else
      return "#{implicit_version(mod)}: #{versions.last}"
    end
  end

  def resolve_constraints(dependencies, source = [{:name => :you}], seen = {}, action = @action)
    dependencies = dependencies.map do |mod, range|
      source.last[:dependency] = range

      @conditions[mod] << {
        :module     => source.last[:name],
        :version    => source.last[:version],
        :dependency => range,
        :queued     => true
      }

      if forced?
        range = Puppet::Module.parse_range(@version) rescue Puppet::Module.parse_range('>= 0.0.0')
      else
        range = (@conditions[mod]).map do |r|
          Puppet::Module.parse_range(r[:dependency]) rescue Puppet::Module.parse_range('>= 0.0.0')
        end.inject(&:&)
      end

      if @action == :install && seen.include?(mod)
        next if range === seen[mod][:semver]

        req_module   = @module_name
        req_versions = @versions["#{@module_name}"].map { |v| v[:semver] }
        raise InvalidDependencyCycleError,
          :module_name       => mod,
          :source            => (source + [{ :name => mod, :version => source.last[:dependency] }]),
          :requested_module  => req_module,
          :requested_version => @version || annotated_version(req_module, req_versions),
          :conditions        => @conditions
      end

      if !(forced? || @installed[mod].empty? || source.last[:name] == :you)
        next if range === SemanticPuppet::Version.parse(@installed[mod].first.version)
        action = :upgrade
      elsif @installed[mod].empty?
        action = :install
      end

      if action == :upgrade
        @conditions.each { |_, conds| conds.delete_if { |c| c[:module] == mod } }
      end

      versions = @versions["#{mod}"].select { |h| range === h[:semver] }
      valid_versions = versions.select { |x| x[:semver].special == '' }
      valid_versions = versions if valid_versions.empty?

      unless version = valid_versions.last
        req_module   = @module_name
        req_versions = @versions["#{@module_name}"].map { |v| v[:semver] }
        raise NoVersionsSatisfyError,
          :requested_name    => req_module,
          :requested_version => @version || annotated_version(req_module, req_versions),
          :installed_version => @installed[@module_name].empty? ? nil : @installed[@module_name].first.version,
          :dependency_name   => mod,
          :conditions        => @conditions[mod],
          :action            => @action
      end

      seen[mod] = version

      {
        :module           => mod,
        :version          => version,
        :action           => action,
        :previous_version => @installed[mod].empty? ? nil : @installed[mod].first.version,
        :file             => @urls["#{mod}@#{version[:vstring]}"],
        :path             => action == :install ? @options[:target_dir] : (@installed[mod].empty? ? @options[:target_dir] : @installed[mod].first.modulepath),
        :dependencies     => []
      }
    end.compact
    dependencies.each do |mod|
      deps = @remote["#{mod[:module]}@#{mod[:version][:vstring]}"].sort_by(&:first)
      mod[:dependencies] = resolve_constraints(deps, source + [{ :name => mod[:module], :version => mod[:version][:vstring] }], seen, :install)
    end unless @ignore_dependencies
    return dependencies
  end

  def download_tarballs(graph, default_path, forge)
    graph.map do |release|
      begin
        if release[:tarball]
          cache_path = Pathname(release[:tarball])
        else
          cache_path = forge.retrieve(release[:file])
        end
      rescue OpenURI::HTTPError => e
        raise RuntimeError, _("Could not download module: %{message}") % { message: e.message }, e.backtrace
      end

      [
        { (release[:path] ||= default_path) => cache_path},
        *download_tarballs(release[:dependencies], default_path, forge)
      ]
    end.flatten
  end

  def forced?
    options[:force]
  end

  def add_module_name_constraints_to_graph(graph)
    # Puppet modules are installed by "module name", but resolved by
    # "full name" (including namespace).  So that we don't run into
    # problems at install time, we should reject any solution that
    # depends on multiple nodes with the same "module name".
    graph.add_graph_constraint('PMT') do |nodes|
      names = nodes.map { |x| x.dependency_names + [ x.name ] }.flatten
      names = names.map { |x| x.tr('/', '-') }.uniq
      names = names.map { |x| x[/-(.*)/, 1] }
      names.length == names.uniq.length
    end
  end
end
