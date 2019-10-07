class Puppet::Parser::Compiler
  # Validator that asserts that all capability resources that are referenced by 'consume' or 'require' has
  # been exported by some other resource in the environment
  class CatalogValidator::EnvironmentRelationshipValidator < CatalogValidator

    def validate
      assumed_exports = {}
      exported = {}
      catalog.resources.each do |resource|
        next unless resource.is_a?(Puppet::Parser::Resource)
        resource.eachparam do |param|
          pclass = Puppet::Type.metaparamclass(param.name)
          validate_relationship(resource, param, assumed_exports, exported) if !pclass.nil? && pclass < Puppet::Type::RelationshipMetaparam
        end
      end
      assumed_exports.each_pair do |key, (param, cap)|
        raise CatalogValidationError.new(_("Capability '%{cap}' referenced by '%{param}' is never exported") % { cap: cap, param: param.name }, param.file, param.line) unless exported.include?(key)
      end
      nil
    end

    private

    def validate_relationship(resource, param, assumed_exports, exported)
      case param.name
      when :require, :consume
        add_capability_ref(param, param.value, assumed_exports)
      when :export
        add_exported(resource, param, param.value, exported)
      end
    end

    def add_capability_ref(param, value, assumed_exports)
      case value
      when Array
        value.each { |v| add_capability_ref(param, v, assumed_exports) }
      when Puppet::Resource
        rt = value.resource_type
        unless rt.nil? || !rt.is_capability?
          title_key = catalog.title_key_for_ref(value.ref)
          assumed_exports[title_key] = [param, value]
        end
        nil
      end
    end

    def add_exported(resource, param, value, hash)
      case value
      when Array
        value.each { |v| add_exported(resource, param, v, hash) }
      when Puppet::Resource
        rt = value.resource_type
        unless rt.nil? || !rt.is_capability?
          title_key = catalog.title_key_for_ref(value.ref)
          if hash.include?(title_key)
            raise CatalogValidationError.new(_("'%{value}' is exported by both '%{hash}' and '%{resource}'") % { value: value, hash: hash[title_key], resource: resource }, param.file, param.line)
          else
            hash[title_key] = resource
          end
        end
      end
    end
  end
end
