module Puppet
  class TextDomainService
    def self.create
      if Puppet[:disable_i18n]
        TextDomainService.new
      else
        I18nTextDomainService.new
      end
    end

    def created(env); end
    def evicted(env); end
  end

  class I18nTextDomainService < TextDomainService
    def created(env)
      Puppet::GettextConfig.reset_text_domain(env.name)
      Puppet::ModuleTranslations.load_from_modulepath(env.modules)
    end

    def evicted(env)
      Puppet::GettextConfig.delete_text_domain(env.name)
    end
  end
end
