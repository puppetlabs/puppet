# Abstract class for a catalog validator that can be registered with the compiler to run at
# a certain stage.
class Puppet::Parser::Compiler
  class CatalogValidator
    PRE_FINISH = :pre_finish
    FINAL = :final

    # Returns true if the validator should run at the given stage. The default
    # implementation will only run at stage `FINAL`
    #
    # @param stage [Symbol] One of the stage constants defined in this class
    # @return [Boolean] true if the validator should run at the given stage
    #
    def self.validation_stage?(stage)
      FINAL.equal?(stage)
    end

    attr_reader :catalog

    # @param catalog [Puppet::Resource::Catalog] The catalog to validate
    def initialize(catalog)
      @catalog = catalog
    end

    # Validate some aspect of the catalog and raise a `CatalogValidationError` on failure
    def validate
    end
  end

  class CatalogValidationError < Puppet::Error
    include Puppet::ExternalFileError
  end
end
