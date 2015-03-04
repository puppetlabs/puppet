# encoding: UTF-8

Puppet::Face.define(:module, '1.0.0') do
  action(:list) do
    summary "List installed modules"
    description <<-HEREDOC
      Lists the installed puppet modules. By default, this action scans the
      modulepath from puppet.conf's `[main]` block; use the --modulepath
      option to change which directories are scanned.

      The output of this action includes information from the module's
      metadata, including version numbers and unmet module dependencies.
    HEREDOC
    returns "hash of paths to module objects"

    option "--tree" do
      summary "Whether to show dependencies as a tree view"
    end

    examples <<-'EOT'
      List installed modules:

      $ puppet module list
        /etc/puppetlabs/code/modules
        ├── bodepd-create_resources (v0.0.1)
        ├── puppetlabs-bacula (v0.0.2)
        ├── puppetlabs-mysql (v0.0.1)
        ├── puppetlabs-sqlite (v0.0.1)
        └── puppetlabs-stdlib (v2.2.1)
        /opt/puppetlabs/puppet/modules (no modules installed)

      List installed modules in a tree view:

      $ puppet module list --tree
        /etc/puppetlabs/code/modules
        └─┬ puppetlabs-bacula (v0.0.2)
          ├── puppetlabs-stdlib (v2.2.1)
          ├─┬ puppetlabs-mysql (v0.0.1)
          │ └── bodepd-create_resources (v0.0.1)
          └── puppetlabs-sqlite (v0.0.1)
        /opt/puppetlabs/puppet/modules (no modules installed)

      List installed modules from a specified environment:

      $ puppet module list --environment production
        /etc/puppetlabs/code/modules
        ├── bodepd-create_resources (v0.0.1)
        ├── puppetlabs-bacula (v0.0.2)
        ├── puppetlabs-mysql (v0.0.1)
        ├── puppetlabs-sqlite (v0.0.1)
        └── puppetlabs-stdlib (v2.2.1)
        /opt/puppetlabs/puppet/modules (no modules installed)

      List installed modules from a specified modulepath:

      $ puppet module list --modulepath /opt/puppetlabs/puppet/modules
        /opt/puppetlabs/puppet/modules (no modules installed)
    EOT

    when_invoked do |options|
      Puppet::ModuleTool.set_option_defaults(options)
      environment = options[:environment_instance]

      {
        :environment     => environment,
        :modules_by_path => environment.modules_by_path,
      }
    end

    when_rendering :console do |result, options|
      environment     = result[:environment]
      modules_by_path = result[:modules_by_path]

      output = ''

      warn_unmet_dependencies(environment)

      environment.modulepath.each do |path|
        modules = modules_by_path[path]
        no_mods = modules.empty? ? ' (no modules installed)' : ''
        output << "#{path}#{no_mods}\n"

        if options[:tree]
          # The modules with fewest things depending on them will be the
          # parent of the tree.  Can't assume to start with 0 dependencies
          # since dependencies may be cyclical.
          modules_by_num_requires = modules.sort_by {|m| m.required_by.size}
          @seen = {}
          tree = list_build_tree(modules_by_num_requires, [], nil,
            :label_unmet => true, :path => path, :label_invalid => false)
        else
          tree = []
          modules.sort_by { |mod| mod.forge_name or mod.name  }.each do |mod|
            tree << list_build_node(mod, path, :label_unmet => false,
                      :path => path, :label_invalid => true)
          end
        end

        output << Puppet::ModuleTool.format_tree(tree)
      end

      output
    end
  end

  def warn_unmet_dependencies(environment)
    error_types = {
      :non_semantic_version => {
        :title => "Non semantic version dependency"
      },
      :missing => {
        :title => "Missing dependency"
      },
      :version_mismatch => {
        :title => "Module '%s' (v%s) fails to meet some dependencies:"
      }
    }

    @unmet_deps = {}
    error_types.each_key do |type|
      @unmet_deps[type] = Hash.new do |hash, key|
        hash[key] = { :errors => [], :parent => nil }
      end
    end

    # Prepare the unmet dependencies for display on the console.
    environment.modules.sort_by {|mod| mod.name}.each do |mod|
      unmet_grouped = Hash.new { |h,k| h[k] = [] }
      unmet_grouped = mod.unmet_dependencies.inject(unmet_grouped) do |acc, dep|
        acc[dep[:reason]] << dep
        acc
      end
      unmet_grouped.each do |type, deps|
        unless deps.empty?
          unmet_grouped[type].sort_by { |dep| dep[:name] }.each do |dep|
            dep_name           = dep[:name].gsub('/', '-')
            installed_version  = dep[:mod_details][:installed_version]
            version_constraint = dep[:version_constraint]
            parent_name        = dep[:parent][:name].gsub('/', '-')
            parent_version     = dep[:parent][:version]

            msg = "'#{parent_name}' (#{parent_version})"
            msg << " requires '#{dep_name}' (#{version_constraint})"
            @unmet_deps[type][dep[:name]][:errors] << msg
            @unmet_deps[type][dep[:name]][:parent] = {
              :name    => dep[:parent][:name],
              :version => parent_version
            }
            @unmet_deps[type][dep[:name]][:version] = installed_version
          end
        end
      end
    end

    # Display unmet dependencies by category.
    error_display_order = [:non_semantic_version, :version_mismatch, :missing]
    error_display_order.each do |type|
      unless @unmet_deps[type].empty?
        @unmet_deps[type].keys.sort_by {|dep| dep }.each do |dep|
          name    = dep.gsub('/', '-')
          title   = error_types[type][:title]
          errors  = @unmet_deps[type][dep][:errors]
          version = @unmet_deps[type][dep][:version]

          msg = case type
                when :version_mismatch
                  title % [name, version] + "\n"
                when :non_semantic_version
                  title + " '#{name}' (v#{version}):\n"
                else
                  title + " '#{name}':\n"
                end

          errors.each { |error_string| msg << "  #{error_string}\n" }
          Puppet.warning msg.chomp
        end
      end
    end
  end

  # Prepare a list of module objects and their dependencies for print in a
  # tree view.
  #
  # Returns an Array of Hashes
  #
  # Example:
  #
  #   [
  #     {
  #       :text => "puppetlabs-bacula (v0.0.2)",
  #       :dependencies=> [
  #         { :text => "puppetlabs-stdlib (v2.2.1)", :dependencies => [] },
  #         {
  #           :text => "puppetlabs-mysql (v1.0.0)"
  #           :dependencies => [
  #             {
  #               :text => "bodepd-create_resources (v0.0.1)",
  #               :dependencies => []
  #             }
  #           ]
  #         },
  #         { :text => "puppetlabs-sqlite (v0.0.1)", :dependencies => [] },
  #       ]
  #     }
  #   ]
  #
  # When the above data structure is passed to Puppet::ModuleTool.build_tree
  # you end up with something like this:
  #
  #   /etc/puppetlabs/code/modules
  #   └─┬ puppetlabs-bacula (v0.0.2)
  #     ├── puppetlabs-stdlib (v2.2.1)
  #     ├─┬ puppetlabs-mysql (v1.0.0)
  #     │ └── bodepd-create_resources (v0.0.1)
  #     └── puppetlabs-sqlite (v0.0.1)
  #
  def list_build_tree(list, ancestors=[], parent=nil, params={})
    list.map do |mod|
      next if @seen[(mod.forge_name or mod.name)]
      node = list_build_node(mod, parent, params)
      @seen[(mod.forge_name or mod.name)] = true

      unless ancestors.include?(mod)
        node[:dependencies] ||= []
        missing_deps = mod.unmet_dependencies.select do |dep|
          dep[:reason] == :missing
        end
        missing_deps.map do |mis_mod|
          str = "#{colorize(:bg_red, 'UNMET DEPENDENCY')} #{mis_mod[:name].gsub('/', '-')} "
          str << "(#{colorize(:cyan, mis_mod[:version_constraint])})"
          node[:dependencies] << { :text => str }
        end
        node[:dependencies] += list_build_tree(mod.dependencies_as_modules,
          ancestors + [mod], mod, params)
      end

      node
    end.compact
  end

  # Prepare a module object for print in a tree view.  Each node in the tree
  # must be a Hash in the following format:
  #
  #    { :text => "puppetlabs-mysql (v1.0.0)" }
  #
  # The value of a module's :text is affected by three (3) factors: the format
  # of the tree, its dependency status, and the location in the modulepath
  # relative to its parent.
  #
  # Returns a Hash
  #
  def list_build_node(mod, parent, params)
    str = ''
    str << (mod.forge_name ? mod.forge_name.gsub('/', '-') : mod.name)
    str << ' (' + colorize(:cyan, mod.version ? "v#{mod.version}" : '???') + ')'

    unless File.dirname(mod.path) == params[:path]
      str << " [#{File.dirname(mod.path)}]"
    end

    if @unmet_deps[:version_mismatch].include?(mod.forge_name)
      if params[:label_invalid]
        str << '  ' + colorize(:red, 'invalid')
      elsif parent.respond_to?(:forge_name)
        unmet_parent = @unmet_deps[:version_mismatch][mod.forge_name][:parent]
        if (unmet_parent[:name] == parent.forge_name &&
            unmet_parent[:version] == "v#{parent.version}")
          str << '  ' + colorize(:red, 'invalid')
        end
      end
    end

    { :text => str }
  end
end
