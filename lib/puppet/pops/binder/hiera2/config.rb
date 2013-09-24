module Puppet::Pops::Binder::Hiera2

  # Class holding the Hiera2 Configuration
  # The configuration is obtained from the file 'hiera.yaml'
  # that must reside in the root directory of the module
  # @api public
  #
  class Puppet::Pops::Binder::Hiera2::Config
    DEFAULT_HIERARCHY_2 = [ ['osfamily', '${osfamily}', 'data/osfamily/${osfamily}'], ['common', 'true', 'data/common']]
    DEFAULT_HIERARCHY_3 = [
      { 'category' => 'osfamily',
        'value'    => '${osfamily}', 
        'path'     => 'osfamily/${osfamily}'
      },
      { 'category' => 'common',
        'value'   => 'true',
        'path'    => 'common'
      }
    ]
    DEFAULT_DATADIR = 'data'
    DEFAULT_BACKENDS = ['yaml', 'json']

    if defined?(::Psych::SyntaxError)
      YamlLoadExceptions = [::StandardError, ::ArgumentError, ::Psych::SyntaxError]
    else
      YamlLoadExceptions = [::StandardError, ::ArgumentError]
    end

    # Returns a list of configured backends.
    #
    # @return [Array<String>] backend names
    attr_reader :backends

    # The datadir relative to the hiera.yaml file, prepended to paths
    attr_reader :data_dir

    # Root directory of the module holding the configuration
    #
    # @return [String] An absolute path
    attr_reader :module_dir

    # The bindings hierarchy is an array of categorizations where the
    # array for each category has exactly three elements - the categorization name,
    # category value, and the path that is later used by the backend to read
    # the bindings for that category
    #
    # @return [Array<Array(String, String, String)>]
    # @api public
    attr_reader :hierarchy

    # The configuration file version. (This implementation supports 2 and 3
    # @return [String]
    # @api public
    #
    attr_reader :version

    # Creates a new Config. The configuration is loaded from the file 'hiera.yaml' which
    # is expected to be found in the given module_dir.
    #
    # @param module_dir [String] The module directory
    # @param diagnostics [DiagnosticProducer] collector of diagnostics
    # @api public
    #
    def initialize(module_dir, diagnostics)
      @module_dir = module_dir
      config_file = File.join(module_dir, 'hiera.yaml')
      validator = ConfigChecker.new(diagnostics)
      begin
        data = YAML.load_file(config_file)
        validator.validate(data, config_file)
        unless diagnostics.errors?
          # if these are missing the result is nil, and they get default values later
          @hierarchy = data['hierarchy']
          @backends = data['backends']
          @version = data['version']
          @data_dir = data['data_dir']
        end
      rescue Errno::ENOENT
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, config_file)
      rescue Errno::ENOTDIR
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, config_file)
      rescue ::SyntaxError => e
        diagnostics.accept(Issues::CONFIG_FILE_SYNTAX_ERROR, e)
      rescue *YamlLoadExceptions => e
        diagnostics.accept(Issues::CONFIG_FILE_SYNTAX_ERROR, e)
      end
      @data_dir  ||= DEFAULT_DATADIR
      @backends ||= DEFAULT_BACKENDS
      if version == 3
        @hierarchy ||= DEFAULT_HIERARCHY_3
      else
        @hierarchy ||= DEFAULT_HIERARCHY_2
      end
    end
  end
end
