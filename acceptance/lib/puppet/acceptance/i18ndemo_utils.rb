module Puppet
module Acceptance
  module I18nDemoUtils

    require 'puppet/acceptance/i18n_utils'
    extend Puppet::Acceptance::I18nUtils

    I18NDEMO_NAME = "i18ndemo"
    I18NDEMO_MODULE_NAME = "eputnam-#{I18NDEMO_NAME}"

    def configure_master_system_locale(language)
      language = enable_locale_language(master, language)
      fail_test("puppet server machine is missing #{language} locale. help...") if language.nil?

      on(master, "localectl set-locale LANG=#{language}")
      on(master, "service #{master['puppetservice']} restart")
    end

    def reset_master_system_locale
      language = language_name(master, 'en_US') || 'en_US'
      on(master, "localectl set-locale LANG=#{language}")
      on(master, "service #{master['puppetservice']} restart")
    end

    def install_i18n_demo_module(node, environment=nil)
      env_options = environment.nil? ? '' : "--environment #{environment}"
      on(node, puppet("module install #{I18NDEMO_MODULE_NAME} #{env_options}"))
    end

    def uninstall_i18n_demo_module(node, environment=nil)
      env_options = environment.nil? ? '' : "--environment #{environment}"
      [I18NDEMO_MODULE_NAME, 'puppetlabs-stdlib', 'puppetlabs-translate'].each do |module_name|
        on(node, puppet("module uninstall #{module_name} #{env_options}"), :acceptable_exit_codes => [0,1])
      end
      var_dir = on(node, puppet('config print vardir')).stdout.chomp
      on(node, "rm -rf '#{File.join(var_dir, 'locales', 'ja')}' '#{File.join(var_dir, 'locales', 'fi')}'")
    end
  end
end
end
