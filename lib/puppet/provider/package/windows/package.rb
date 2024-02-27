# frozen_string_literal: true

require_relative '../../../../puppet/provider/package'
require_relative '../../../../puppet/util/windows'

class Puppet::Provider::Package::Windows
  class Package
    extend Enumerable
    extend Puppet::Util::Errors

    include Puppet::Util::Windows::Registry
    extend Puppet::Util::Windows::Registry

    attr_reader :name, :version

    REG_DISPLAY_VALUE_NAMES = ['DisplayName', 'QuietDisplayName']

    def self.reg_value_names_to_load
      REG_DISPLAY_VALUE_NAMES |
        MsiPackage::REG_VALUE_NAMES |
        ExePackage::REG_VALUE_NAMES
    end

    # Enumerate each package. The appropriate package subclass
    # will be yielded.
    def self.each(&block)
      with_key do |key, values|
        name = key.name.match(/^.+\\([^\\]+)$/).captures[0]

        [MsiPackage, ExePackage].find do |klass|
          pkg = klass.from_registry(name, values)
          if pkg
            yield pkg
          end
        end
      end
    end

    # Yield each registry key and its values associated with an
    # installed package. This searches both per-machine and current
    # user contexts, as well as packages associated with 64 and
    # 32-bit installers.
    def self.with_key(&block)
      %w[HKEY_LOCAL_MACHINE HKEY_CURRENT_USER].each do |hive|
        [KEY64, KEY32].each do |mode|
          mode |= KEY_READ
          begin
            self.open(hive, 'Software\Microsoft\Windows\CurrentVersion\Uninstall', mode) do |uninstall|
              each_key(uninstall) do |name, _wtime|
                self.open(hive, "#{uninstall.keyname}\\#{name}", mode) do |key|
                  yield key, values_by_name(key, reg_value_names_to_load)
                end
              end
            end
          rescue Puppet::Util::Windows::Error => e
            raise e unless e.code == Puppet::Util::Windows::Error::ERROR_FILE_NOT_FOUND
          end
        end
      end
    end

    # Get the class that knows how to install this resource
    def self.installer_class(resource)
      fail(_("The source parameter is required when using the Windows provider.")) unless resource[:source]

      case resource[:source]
      when /\.msi"?\Z/i
        # REMIND: can we install from URL?
        # REMIND: what about msp, etc
        MsiPackage
      when /\.exe"?\Z/i
        fail(_("The source does not exist: '%{source}'") % { source: resource[:source] }) unless
          Puppet::FileSystem.exist?(resource[:source]) || resource[:source].start_with?('http://', 'https://')

        ExePackage
      else
        fail(_("Don't know how to install '%{source}'") % { source: resource[:source] })
      end
    end

    def self.munge(value)
      quote(replace_forward_slashes(value))
    end

    def self.replace_forward_slashes(value)
      if value.include?('/')
        value = value.tr('/', "\\")
        Puppet.debug('Package source parameter contained /s - replaced with \\s')
      end
      value
    end

    def self.quote(value)
      value.include?(' ') ? %Q("#{value.gsub(/"/, '\"')}") : value
    end

    def self.get_display_name(values)
      return if values.nil?
      return values['DisplayName'] if values['DisplayName'] && values['DisplayName'].length > 0
      return values['QuietDisplayName'] if values['QuietDisplayName'] && values['QuietDisplayName'].length > 0

      ''
    end

    def initialize(name, version)
      @name = name
      @version = version
    end
  end
end

require_relative '../../../../puppet/provider/package/windows/msi_package'
require_relative '../../../../puppet/provider/package/windows/exe_package'
