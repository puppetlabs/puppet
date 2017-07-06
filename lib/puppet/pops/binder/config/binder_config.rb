module Puppet::Pops::Binder::Config
  # Class holding the Binder Configuration
  # The configuration is obtained from the file 'binder_config.yaml'
  # that must reside in the root directory of the site
  # @api public
  #
  class BinderConfig

    # The layering configuration is an array of layers from most to least significant.
    # Each layer is represented by a Hash containing :name and :include and optionally :exclude
    #
    # @return [Array<Hash<String, String>, Hash<String, Array<String>>]
    # @api public
    #
    attr_reader :layering_config

    # @return <Hash<String, String>] ({}) optional mapping of bindings-scheme to handler class name
    attr_reader :scheme_extensions


    # @return [String] the loaded config file
    attr_accessor :config_file

    DEFAULT_LAYERS = [
      { 'name' => 'site',    'include' => [ 'confdir:/default?optional'] },
      { 'name' => 'modules', 'include' => [ 'module:/*::default', 'module:/*::metadata'] },
    ]

    DEFAULT_SCHEME_EXTENSIONS = {}

    def default_config()
      # This is hardcoded now, but may be a user supplied default configuration later
      {'version' => 1, 'layers' => default_layers }
    end

    def confdir()
      Puppet.settings[:confdir]
    end

    # Creates a new Config. The configuration is loaded from the file 'binder_config.yaml' which
    # is expected to be found in confdir.
    #
    # @param diagnostics [DiagnosticProducer] collector of diagnostics
    # @api public
    #
    def initialize(diagnostics)
      @config_file = Puppet.settings[:binder_config]
      # if file is stated, it must exist
      # otherwise it is optional $confdir/binder_conf.yaml
      # and if that fails, the default
      case @config_file
      when NilClass
        # use the config file if it exists
        rootdir = confdir
        if rootdir.is_a?(String)
          expanded_config_file = File.expand_path(File.join(rootdir, '/binder_config.yaml'))
          if Puppet::FileSystem.exist?(expanded_config_file)
            @config_file = expanded_config_file
          end
        else
          raise ArgumentError, "No Puppet settings 'confdir', or it is not a String"
        end
      when String
        unless Puppet::FileSystem.exist?(@config_file)
          raise ArgumentError, "Cannot find the given binder configuration file '#{@config_file}'"
        end
      else
        raise ArgumentError, "The setting binder_config is expected to be a String, got: #{@config_file.class.name}."
      end
      unless @config_file.is_a?(String) && Puppet::FileSystem.exist?(@config_file)
        @config_file = nil # use defaults
      end

      validator = BinderConfigChecker.new(diagnostics)
      begin
        data = @config_file ? YAML.load_file(@config_file) : default_config()
        validator.validate(data, @config_file)
      rescue Errno::ENOENT
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, @config_file)
      rescue Errno::ENOTDIR
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, @config_file)
      rescue ::SyntaxError => e
        diagnostics.accept(Issues::CONFIG_FILE_SYNTAX_ERROR, @config_file, :detail => e.message)
      end

      unless diagnostics.errors?
        @layering_config   = data['layers'] || default_layers
        @scheme_extensions = (data['extensions'] && data['extensions']['scheme_handlers'] || default_scheme_extensions)
      else
        @layering_config = []
        @scheme_extensions = {}
      end
    end

    # The default_xxx methods exists to make it easier to do mocking in tests.

    # @api private
    def default_layers
      DEFAULT_LAYERS
    end

    # @api private
    def default_scheme_extensions
      DEFAULT_SCHEME_EXTENSIONS
    end
  end
end
