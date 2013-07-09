module Puppet::Pops::Binder::Hiera2

  # Validates the consistency of a Hiera2::Config
  class ConfigChecker

    # Create an instance with a diagnostic producer that will receive the result during validation
    # @param diangostics [DiagnosticProducer] The producer that will receive the diagnostic
    def initialize(diagnostics)
      @diagnostics = diagnostics
    end

    # Validate the consistency of the given data. Diagnostics will be emitted to the DiagnosticProducer
    # that was set when this checker was created
    #
    # @param data [Object] The data read from the config file
    # @param config_file [String] The full path of the file. Used in error messages
    def validate(data, config_file)
      if data.is_a?(Hash)
        check_hierarchy(data['hierarchy'], config_file)
        check_backends(data['backends'], config_file)
      else
        @diagnostics.accept(Issues::CONFIG_IS_NOT_HASH, config_file)
      end
    end

    private

    def check_hierarchy(hierarchy, config_file)
      if !hierarchy.is_a?(Hash) || hierarchy.empty?
        @diagnostics.accept(Issues::MISSING_HIERARCHY, config_file)
      else
        hierarchy.each_pair do |key,value|
          unless value.is_a?(Array) && value.length() == 2
            @diagnostics.accept(Issues::CATEGORY_MUST_BE_TWO_ELEMENT_ARRAY, config_file, { :key => key })
          end
        end
      end
    end

    def check_backends(backends, config_file)
      if !backends.is_a?(Array) || backends.empty?
        @diagnostics.accept(Issues::MISSING_BACKENDS, config_file)
      else
        backends.each do |key|
          Backend.check_key(key, config_file, @diagnostics)
        end
      end
    end
  end
end
