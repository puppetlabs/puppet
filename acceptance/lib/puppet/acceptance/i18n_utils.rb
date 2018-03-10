module Puppet
  module Acceptance
    module I18nUtils

      # try to enable the locale's for a given language on the agent and return the preferred language name
      #
      # @param agent [string] the agent to check the locale configuration on
      # @param language [string] the language attempt to configure if needed
      # @return language [string] the language string to use on the agent node, will return nil if not available
      def enable_locale_language(agent, language)
        if agent['platform'] =~ /ubuntu/
          on(agent, 'locale -a') do |locale_result|
            if locale_result.stdout !~ /#{language}/
              on(agent, "locale-gen --lang #{language}")
            end
          end
        elsif agent['platform'] =~ /debian/
          on(agent, 'locale -a') do |locale_result|
            if locale_result.stdout !~ /#{language}/
              on(agent, "cp /etc/locale.gen /etc/locale.gen.orig ; sed -e 's/# #{language}/#{language}/' /etc/locale.gen.orig > /etc/locale.gen")
              on(agent, 'locale-gen')
            end
          end
        end
        return language_name(agent, language)
      end

      # figure out the preferred language string for the requested language if the language is configured on the system
      def language_name(agent, language)
        step "PLATFORM #{agent['platform']}"
          on(agent, 'locale -a') do |locale_result|
            ["#{language}.utf8", "#{language}.UTF-8", language].each do |lang|
              return lang if locale_result.stdout =~ /#{lang}/
            end
          end
        return nil
      end
    end
  end
end
