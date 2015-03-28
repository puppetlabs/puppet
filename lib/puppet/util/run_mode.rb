require 'etc'

module Puppet
  module Util
    class RunMode
      def initialize(name)
        @name = name.to_sym
      end

      attr :name

      def self.[](name)
        @run_modes ||= {}
        if Puppet.features.microsoft_windows?
          @run_modes[name] ||= WindowsRunMode.new(name)
        else
          @run_modes[name] ||= UnixRunMode.new(name)
        end
      end

      def master?
        name == :master
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

      ##
      # select the system or the user directory depending on the context of
      # this process.  The most common use is determining filesystem path
      # values for confdir and vardir.  The intended semantics are:
      # {http://projects.puppetlabs.com/issues/16637 #16637} for Puppet 3.x
      #
      # @todo this code duplicates {Puppet::Settings#which\_configuration\_file}
      #   as described in {http://projects.puppetlabs.com/issues/16637 #16637}
      def which_dir( system, user )
        File.expand_path(if Puppet.features.root? then system else user end)
      end
    end

    class UnixRunMode < RunMode
      def conf_dir
        which_dir("/etc/puppetlabs/puppet", "~/.puppet")
      end

      def code_dir
        which_dir("/etc/puppetlabs/code", "~/.puppet/code")
      end

      def var_dir
        which_dir("/opt/puppetlabs/puppet/cache", "~/.puppet/var")
      end

      def run_dir
        which_dir("/var/run/puppetlabs", "~/.puppet/var/run")
      end

      def log_dir
        which_dir("/var/log/puppetlabs/puppet", "~/.puppet/var/log")
      end
    end

    class WindowsRunMode < RunMode
      def conf_dir
        which_dir(File.join(windows_common_base("puppet/etc")), "~/.puppet")
      end

      def code_dir
        which_dir(File.join(windows_common_base("code")), "~/.puppet/code")
      end

      def var_dir
        which_dir(File.join(windows_common_base("puppet/cache")), "~/.puppet/var")
      end

      def run_dir
        which_dir(File.join(windows_common_base("puppet/var/run")), "~/.puppet/var/run")
      end

      def log_dir
        which_dir(File.join(windows_common_base("puppet/var/log")), "~/.puppet/var/log")
      end

    private

      def windows_common_base(*extra)
        [Dir::COMMON_APPDATA, "PuppetLabs"] + extra
      end
    end
  end
end
