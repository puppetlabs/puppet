# frozen_string_literal: true

class Puppet::Parser::Compiler
  # Validator that asserts relationship metaparameters refer to valid resources
  class CatalogValidator::RelationshipValidator < CatalogValidator
    def validate
      catalog.resources.each do |resource|
        next unless resource.is_a?(Puppet::Parser::Resource)
        next if resource.virtual?

        resource.eachparam do |param|
          pclass = Puppet::Type.metaparamclass(param.name)
          validate_relationship(param) if !pclass.nil? && pclass < Puppet::Type::RelationshipMetaparam
        end
      end
      nil
    end

    private

    def validate_relationship(param)
      # the referenced resource must exist
      refs = param.value.is_a?(Array) ? param.value.flatten : [param.value]
      refs.each do |r|
        next if r.nil? || r == :undef

        res = r.to_s
        begin
          found = catalog.resource(res)
        rescue ArgumentError => e
          # Raise again but with file and line information
          raise CatalogValidationError.new(e.message, param.file, param.line)
        end
        unless found
          msg = _("Could not find resource '%{res}' in parameter '%{param}'") % { res: res, param: param.name.to_s }
          raise CatalogValidationError.new(msg, param.file, param.line)
        end
      end
    end
  end
end
