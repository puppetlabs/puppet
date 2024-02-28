# frozen_string_literal: true

module Puppet
  module Util
    module Platform
      FIPS_STATUS_FILE = "/proc/sys/crypto/fips_enabled"
      WINDOWS_FIPS_REGISTRY_KEY = 'System\\CurrentControlSet\\Control\\Lsa\\FipsAlgorithmPolicy'

      def windows?
        # Ruby only sets File::ALT_SEPARATOR on Windows and the Ruby standard
        # library uses that to test what platform it's on. In some places we
        # would use Puppet.features.microsoft_windows?, but this method can be
        # used to determine the behavior of the underlying system without
        # requiring features to be initialized and without side effect.
        !!File::ALT_SEPARATOR
      end
      module_function :windows?

      def solaris?
        RUBY_PLATFORM.include?('solaris')
      end
      module_function :solaris?

      def default_paths
        return [] if windows?

        %w[/usr/sbin /sbin]
      end
      module_function :default_paths

      @fips_enabled = if windows?
                        require 'win32/registry'

                        begin
                          Win32::Registry::HKEY_LOCAL_MACHINE.open(WINDOWS_FIPS_REGISTRY_KEY) do |reg|
                            reg.values.first == 1
                          end
                        rescue Win32::Registry::Error
                          false
                        end
                      else
                        File.exist?(FIPS_STATUS_FILE) &&
                          File.read(FIPS_STATUS_FILE, 1) == '1'
                      end

      def fips_enabled?
        @fips_enabled
      end
      module_function :fips_enabled?

      def self.jruby?
        RUBY_PLATFORM == 'java'
      end

      def jruby_fips?
        @@jruby_fips ||= if RUBY_PLATFORM == 'java'
                           require 'java'

                           begin
                             require 'openssl'
                             false
                           rescue LoadError, NameError
                             true
                           end
                         else
                           false
                         end
      end
      module_function :jruby_fips?
    end
  end
end
