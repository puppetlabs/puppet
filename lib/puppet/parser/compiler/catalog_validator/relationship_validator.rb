class Puppet::Parser::Compiler
  # Validator that asserts that only 'require', 'consume', and 'export' is used when declaring relationships
  # to capability resources.
  class CatalogValidator::RelationshipValidator < CatalogValidator
    def validate
      catalog.resources.each do |resource|
        next unless resource.is_a?(Puppet::Parser::Resource)
        resource.eachparam do |param|
          pclass = Puppet::Type.metaparamclass(param.name)
          validate_relationship(param) if !pclass.nil? && pclass < Puppet::Type::RelationshipMetaparam
        end
      end
      nil
    end

    private

    def validate_relationship(param)
      unless [:require, :consume, :export].find {|pname| pname == param.name }
        raise CatalogValidationError.new("'#{param.name}' is not a valid relationship to a capability", param.file, param.line) if has_capability?(param.value)
      end
    end

    def has_capability?(value)
      case value
      when Array
        value.find { |v| has_capability?(v) }
      when Puppet::Resource
        rt = value.resource_type
        !rt.nil? && rt.is_capability?
      else
        false
      end
    end
  end
end


