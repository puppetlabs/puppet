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

    def default_config()
      # This is hardcoded now, but may be a user supplied default configuration later
      {'layers' => [
        { 'name' => 'site',    'include' => 'confdir-hiera:/'  },
        { 'name' => 'modules', 'include' => 'module-hiera:/*/' },
      ],
      'categories' => [
        ['node',        "${::fqdn}"],
        ['environment', "${environment}"],
        ['common',      "true"]
        ]
      }
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
        @layering_config = data['layers']
        @categorization = data['categories']
      else
        @layering_config = []
        @categorization = {}
      end
    end
  end
end
