class Puppet::Parser::Compiler
  # Validator that asserts that only application components can appear inside a site.
  class CatalogValidator::SiteValidator < CatalogValidator
    def self.validation_stage?(stage)
      PRE_FINISH.equal?(stage)
    end

    def validate
      the_site_resource = catalog.resource('Site', 'site')
      return unless the_site_resource

      catalog.downstream_from_vertex(the_site_resource).keys.each do |r|
        unless r.is_application_component? || r.resource_type.application?
          raise CatalogValidationError.new("Only application components can appear inside a site - #{r} is not allowed", r.file, r.line)
        end
      end
    end
  end
end

