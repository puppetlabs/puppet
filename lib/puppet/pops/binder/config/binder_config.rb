module Puppet::Pops::Binder::Config
  # Class holding the Binder Configuration
  # The configuration is obtained from the file 'binder_config.yaml'
  # that must reside in the root directory of the site
  # @api public
  #
  class BinderConfig

    # The bindings hierarchy is an array of categorizations where the
    # array for each category has exactly three elements - the categorization name,
    # category value, and the path that is later used by the backend to read
    # the bindings for that category
    #
    # @return [Array<Hash<String, String>, Hash<String, Array<String>>]
    # @api public
    #
    attr_reader :layering_config

    # @return [Array<Array(String, String)>] Array of Category tuples where Strings are not evaluated.
    # @api public
    #
    attr_reader :categorization

    # @return <Hash<String, String>] ({}) optional mapping of bindings-scheme to handler class name
    attr_reader :scheme_extensions

    # @return <Hash<String, String>] ({}) optional mapping of hiera backend name to backend class name
    attr_reader :hiera_backends

    # @return [String] the loaded config file
    attr_accessor :config_file

    DEFAULT_LAYERS = [
      { 'name' => 'site',    'include' => ['confdir-hiera:/', 'confdir:/default?optional']  },
      { 'name' => 'modules', 'include' => ['module-hiera:/*/', 'module:/*::default'] },
    ]

    DEFAULT_CATEGORIES = [
      ['node',        "${fqdn}"],
      ['osfamily',    "${osfamily}"],
      ['environment', "${environment}"],
      ['common',      "true"]
    ]

    DEFAULT_SCHEME_EXTENSIONS = {}

    DEFAULT_HIERA_BACKENDS_EXTENSIONS = {}

    def default_config()
      # This is hardcoded now, but may be a user supplied default configuration later
      {'version' => 1, 'layers' => default_layers, 'categories' => default_categories}
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
          if Puppet::FileSystem::File.exist?(expanded_config_file)
            @config_file = expanded_config_file
          end
        else
          raise ArgumentError, "No Puppet settings 'confdir', or it is not a String"
        end
      when String
        unless Puppet::FileSystem::File.exist?(@config_file)
          raise ArgumentError, "Cannot find the given binder configuration file '#{@config_file}'"
        end
      else
        raise ArgumentError, "The setting binder_config is expected to be a String, got: #{@config_file.class.name}."
      end
      unless @config_file.is_a?(String) && Puppet::FileSystem::File.exist?(@config_file)
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
        @layering_config   = data['layers'] or default_layers
        @categorization    = data['categories'] or default_categories
        @scheme_extensions = (data['extensions'] and data['extensions']['scheme_handlers'] or default_scheme_extensions)
        @hiera_backends    = (data['extensions'] and data['extensions']['hiera_backends'] or default_hiera_backends_extensions)
      else
        @layering_config = []
        @categorization = {}
        @scheme_extensions = {}
        @hiera_backends = {}
      end
    end

    # The default_xxx methods exists to make it easier to do mocking in tests.

    # @api private
    def default_layers
      DEFAULT_LAYERS
    end

    # @api private
    def default_categories
      DEFAULT_CATEGORIES
    end

    # @api private
    def default_scheme_extensions
      DEFAULT_SCHEME_EXTENSIONS
    end

    # @api private
    def default_hiera_backends_extensions
      DEFAULT_HIERA_BACKENDS_EXTENSIONS
    end
  end
end
