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

    DEFAULT_LAYERS = [
      { 'name' => 'site',    'include' => ['confdir-hiera:/', 'confdir:/default?optional']  },
      { 'name' => 'modules', 'include' => ['module-hiera:/*/', 'module:/*::default'] },
    ]

    DEFAULT_CATEGORIES = [
      ['node',        "${::fqdn}"],
      ['osfamily',    "${osfamily}"],
      ['environment', "${environment}"],
      ['common',      "true"]
    ]

    DEFAULT_SCHEME_EXTENSIONS = {}
    DEFAULT_HIERA_BACKENDS_EXTENSIONS = {}

    def default_config()
      # This is hardcoded now, but may be a user supplied default configuration later
      {'version' => 1, 'layers' => DEFAULT_LAYERS, 'categories' => DEFAULT_CATEGORIES}
    end

    def confdir()
      Puppet.settings[:confdir]
    end

    # Creates a new Config. The configuration is loaded from the file 'binder_config.yaml' which
    # is expected to be found in confdir.
    #
    # @param config_dir [String] The directory the configuration should be loaded from
    # @param diagnostics [DiagnosticProducer] collector of diagnostics
    # @api public
    #
    def initialize(diagnostics)
      rootdir = confdir
      if rootdir.is_a?(String)
        expanded_config_file = File.expand_path(File.join(rootdir, '/binder_config.yaml'))
        if File.exist?(expanded_config_file)
          config_file = expanded_config_file
        end
      else
        raise ArgumentError, "No Puppet settings 'confdir', or it is not a String"
      end

      validator = BinderConfigChecker.new(diagnostics)
      begin
        data = config_file ? YAML.load_file(config_file) : default_config()
        validator.validate(data, config_file)
      rescue Errno::ENOENT
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, config_file)
      rescue ::SyntaxError => e
        diagnostics.accept(Issues::CONFIG_FILE_SYNTAX_ERROR, config_file, :detail => e.message)
      end

      unless diagnostics.errors?
        @layering_config = data['layers'] or DEFAULT_LAYERS
        @categorization = data['categories'] or DEFAULT_CATEGORIES
        @scheme_extensions = (data['extensions'] and data['extensions']['scheme_handlers'] or DEFAULT_SCHEME_EXTENSIONS)
        @hiera_backends = (data['extensions'] and data['extensions']['hiera_backends'] or DEFAULT_HIERA_BACKENDS_EXTENSIONS)
      else
        @layering_config = []
        @categorization = {}
        @scheme_extensions = {}
        @hiera_backends = {}
      end
    end
  end
end
