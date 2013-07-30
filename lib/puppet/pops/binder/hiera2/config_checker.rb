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
        # If the version is missing, it is not meaningful to continue
        return unless check_version(data['version'], config_file)
        check_hierarchy(data['hierarchy'], config_file)
        check_backends(data['backends'], config_file)
      else
        @diagnostics.accept(Issues::CONFIG_IS_NOT_HASH, config_file)
      end
    end

    private

    # Version is required and must be >= 2. A warning is issued if version > 2 as this checker is
    # for version 2 only.
    # @return [Boolean] false if it is meaningless to continue checking
    def check_version(version, config_file)
      if version.nil?
        # This is not hiera2 compatible
        @diagnostics.accept(Issues::MISSING_VERSION, config_file)
        return false
      end
      unless version >= 2
        @diagnostics.accept(Issues::WRONG_VERSION, config_file, :expected => 2, :actual => version)
        return false
      end
      unless version == 2
        # it may have a sane subset, hence a different error (configured as warning)
        @diagnostics.accept(Issues::LATER_VERSION, config_file, :expected => 2, :actual => version)
      end
      return true
    end

    def check_hierarchy(hierarchy, config_file)
      if !hierarchy.is_a?(Array) || hierarchy.empty?
        @diagnostics.accept(Issues::MISSING_HIERARCHY, config_file)
      else
        hierarchy.each do |value|
          unless value.is_a?(Array) && value.length() == 3
            @diagnostics.accept(Issues::CATEGORY_MUST_BE_THREE_ELEMENT_ARRAY, config_file)
          end
        end
      end
    end

    def check_backends(backends, config_file)
      if !backends.is_a?(Array) || backends.empty?
        @diagnostics.accept(Issues::MISSING_BACKENDS, config_file)
      end
    end
  end
end
