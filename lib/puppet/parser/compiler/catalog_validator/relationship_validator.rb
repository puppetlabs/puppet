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

    # A hash lookup is 6x avg times faster than find among 3 values.
    CAPABILITY_ACCEPTED_METAPARAMS = {:require => true, :consume => true, :export => true}.freeze

    def validate_relationship(param)
      # when relationship is to a capability
      if has_capability?(param.value)
        unless CAPABILITY_ACCEPTED_METAPARAMS[param.name]
          raise CatalogValidationError.new(
            "'#{param.name}' is not a valid relationship to a capability", 
              param.file, param.line)
        end
      elsif Puppet[:strict] != :off
        # all other relationships requires the referenced resource to exist when mode is strict
        refs = param.value.is_a?(Array) ? param.value.flatten : [param.value]
        refs.each do |r|
          next if r.nil?
          unless catalog.resource(r.to_s)
            msg = "Could not find resource '#{r.to_s}' in parameter '#{param.name.to_s}'"
            if Puppet[:strict] == :error
              raise CatalogValidationError.new(msg, param.file, param.line)
            else
              Puppet.warn_once(:undefined_resources, r.to_s, msg, param.file, param.line)
            end
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


