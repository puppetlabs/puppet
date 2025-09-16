# frozen_string_literal: true

require 'etc'

module Puppet
  module Util
    class RunMode
      def initialize(name)
        @name = name.to_sym
      end

      attr_reader :name

      def self.[](name)
        @run_modes ||= {}
        if Puppet::Util::Platform.windows?
          @run_modes[name] ||= WindowsRunMode.new(name)
        else
          @run_modes[name] ||= UnixRunMode.new(name)
        end
      end

      def server?
        name == :master || name == :server
      end

      def master?
        name == :master || name == :server
      end

      def agent?
        name == :agent
      end

      def user?
        name == :user
      end

      def run_dir
        RunMode[name].run_dir
      end

      def log_dir
        RunMode[name].log_dir
      end

      private

      def find_or_first(*dirs)
        dirs.find {|d| File.directory?(d) } || dirs.first
      end
      ##
      # select the system or the user directory depending on the context of
      # this process.  The most common use is determining filesystem path
      # values for confdir and vardir.  The intended semantics are:
      # {https://projects.puppetlabs.com/issues/16637 #16637} for Puppet 3.x
      #
      # @todo this code duplicates {Puppet::Settings#which\_configuration\_file}
      #   as described in {https://projects.puppetlabs.com/issues/16637 #16637}
      def which_dir(system, user)
        if Puppet.features.root?
          File.expand_path(system)
        else
          File.expand_path(user)
        end
      end
    end

    class UnixRunMode < RunMode
      def conf_dir
        which_dir(find_or_first("/etc/puppetlabs/puppet", "/etc/puppet"), "~/.puppetlabs/etc/puppet")
      end

      def code_dir
        which_dir(find_or_first("/etc/puppetlabs/code", "/etc/puppet/code"), "~/.puppetlabs/etc/code")
      end

      def var_dir
        which_dir(find_or_first("/opt/puppetlabs/puppet/cache", "/var/cache/puppet"), "~/.puppetlabs/opt/puppet/cache")
      end

      def public_dir
        which_dir(find_or_first("/opt/puppetlabs/puppet/public", "/usr/share/puppet/public"), "~/.puppetlabs/opt/puppet/public")
      end

      def run_dir
        which_dir(find_or_first("/var/run/puppetlabs", "/run/puppet"), "~/.puppetlabs/var/run")
      end

      def log_dir
        which_dir(find_or_first("/var/log/puppetlabs/puppet", "/var/log/puppet"), "~/.puppetlabs/var/log")
      end

      def pkg_config_path
        find_or_first('/opt/puppetlabs/puppet/lib/pkgconfig', "/usr/share/pkgconfig", "/usr/lib64/pkgconfig", "/usr/lib/pkgconfig")
      end

      def gem_cmd
        find_or_first('/opt/puppetlabs/puppet/bin/gem', "/usr/bin/gem")
      end

      def common_module_dir
        find_or_first('/opt/puppetlabs/puppet/modules', "/usr/local/lib/puppet-modules")
      end

      def vendor_module_dir
        find_or_first('/opt/puppetlabs/puppet/vendor_modules', "/usr/lib/puppet-modules")
      end
    end

    class WindowsRunMode < RunMode
      def conf_dir
        which_dir(File.join(windows_common_base("puppet/etc")), "~/.puppetlabs/etc/puppet")
      end

      def code_dir
        which_dir(File.join(windows_common_base("code")), "~/.puppetlabs/etc/code")
      end

      def var_dir
        which_dir(File.join(windows_common_base("puppet/cache")), "~/.puppetlabs/opt/puppet/cache")
      end

      def public_dir
        which_dir(File.join(windows_common_base("puppet/public")), "~/.puppetlabs/opt/puppet/public")
      end

      def run_dir
        which_dir(File.join(windows_common_base("puppet/var/run")), "~/.puppetlabs/var/run")
      end

      def log_dir
        which_dir(File.join(windows_common_base("puppet/var/log")), "~/.puppetlabs/var/log")
      end

      def pkg_config_path
        nil
      end

      def gem_cmd
        if (puppet_dir = ENV.fetch('PUPPET_DIR', nil))
          File.join(puppet_dir.to_s, 'bin', 'gem.bat')
        else
          File.join(Gem.default_bindir, 'gem.bat')
        end
      end

      def common_module_dir
        "#{installdir}/puppet/modules" if installdir
      end

      def vendor_module_dir
        "#{installdir}\\puppet\\vendor_modules" if installdir
      end

      private

      def installdir
        ENV.fetch('FACTER_env_windows_installdir', nil)
      end

      def windows_common_base(*extra)
        [ENV.fetch('ALLUSERSPROFILE', nil), "PuppetLabs"] + extra
      end
    end
  end
end
