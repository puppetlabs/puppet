module Puppet::Pops::Binder::Hiera2

  # Class holding the Hiera2 Configuration
  # The configuration is obtained from the file 'hiera_config.yaml'
  # that must reside in the root directory of the module
  class Puppet::Pops::Binder::Hiera2::Config

    # Returns a list of configured backends.
    #
    # @return [Array<String>] backend names
    attr_reader :backends

    # Root directory of the module holding the configuration
    #
    # @return [String] An absolute path
    attr_reader :module_dir

    # The bindings hierarchy is a hash of categorizations where the
    # array for each category has exactly two elements - the category
    # value, and the path that is later used by the backend to read
    # the bindings for the category
    #
    # @return [Hash<String,Array<String>>]
    attr_reader :hierarchy

    # Creates a new Config. The configuration is loaded from the file 'hiera_config.yaml' which
    # is expected to be found in the given module_dir.
    #
    # @param module_dir [String] The module directory
    # @param diagnostics [DiagnosticProducer] collector of diagnostics
    def initialize(module_dir, diagnostics)
      @module_dir = module_dir
      config_file = File.join(module_dir, 'hiera_config.yaml')
      validator = ConfigChecker.new(diagnostics)
      begin
        data = YAML.load_file(config_file)
        validator.validate(data, config_file)
        unless diagnostics.errors?
          @hierarchy = data['hierarchy']
          @backends = data['backends']
        end
      rescue Errno::ENOENT
        diagnostics.accept(Issues::CONFIG_FILE_NOT_FOUND, config_file)
      rescue ::SyntaxError => e
        diagnostics.accept(Issues::CONFIG_FILE_SYNTAX_ERROR, e)
      end
      @hierarchy ||= {}
      @backends ||= []
    end

    # Returns the name of the module. This name will be used as the name
    # for the bindings produced from this module.
    # @return [String] the module name
    def module_name
      File.basename(module_dir)
    end
  end
end
