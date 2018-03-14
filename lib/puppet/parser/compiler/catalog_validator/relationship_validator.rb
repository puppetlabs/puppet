class Puppet::Parser::Compiler
  # Validator that asserts that only 'require', 'consume', and 'export' is used when declaring relationships
  # to capability resources.
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

    # A hash lookup is 6x avg times faster than find among 3 values.
    CAPABILITY_ACCEPTED_METAPARAMS = {:require => true, :consume => true, :export => true}.freeze

    def validate_relationship(param)
      # when relationship is to a capability
      if has_capability?(param.value)
        unless CAPABILITY_ACCEPTED_METAPARAMS[param.name]
          raise CatalogValidationError.new(
            _("'%{param}' is not a valid relationship to a capability") % { param: param.name },
              param.file, param.line)
        end
      else
        # all other relationships requires the referenced resource to exist
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


