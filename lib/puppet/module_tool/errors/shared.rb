module Puppet::Module::Tool::Errors

  class NoVersionsSatisfyError < ModuleToolError
    def initialize(options)
      @requested_name    = options[:requested_name]
      @requested_version = v(options[:requested_version])
      @installed_version = v(options[:installed_version])
      @dependency_name   = options[:dependency_name]
      @conditions        = options[:conditions]
      @action            = options[:action]

      @vstring = if @action == :install
        "#{@requested_version}"
      else
        "#{@installed_version} -> #{@requested_version}"
      end

      super "Could not #{@action} '#{@requested_name}' (#{@vstring}); module '#{@dependency_name}' cannot satisfy dependencies"
    end

    def multiline
      same_mod = @requested_name == @dependency_name

      message = []
      message << "Could not #{@action} module '#{@requested_name}' (#{@vstring})"
      message << "  No version of '#{@dependency_name}' will satisfy dependencies"
      message << "    You specified '#{@requested_name}' (#{@requested_version})" if same_mod
      message += @conditions.select { |c| c[:module] != :you }.sort_by { |c| c[:module] }.map do |c|
        "    '#{c[:module]}' (#{v(c[:version])}) requires '#{@dependency_name}' (#{v(c[:dependency])})"
      end
      message << "    Use `puppet module #{@action} --force` to #{@action} this module anyway" if same_mod
      message << "    Use `puppet module #{@action} --ignore-dependencies` to #{@action} only this module" unless same_mod

      message.join("\n")
    end
  end

  class InvalidDependencyCycleError < ModuleToolError
    def initialize(options)
      @module_name       = options[:module_name]
      @requested_module  = options[:requested_module]
      @requested_version = v(options[:requested_version])
      @conditions        = options[:conditions]
      @source            = options[:source][1..-1]

      super "'#{@requested_module}' (#{@requested_version}) requested; Invalid dependency cycle"
    end

    def multiline
      trace = []
      trace << "You specified '#{@source.first[:name]}' (#{@requested_version})"
      trace += @source[1..-1].map { |m| "which depends on '#{m[:name]}' (#{v(m[:version])})" }

      message = []
      message << "Could not install module '#{@requested_module}' (#{@requested_version})"
      message << "  No version of '#{@module_name}' will satisfy dependencies"
      message << trace.map { |s| "    #{s}" }.join(",\n")
      message << "    Use `puppet module install --force` to install this module anyway"

      message.join("\n")
    end
  end
end
