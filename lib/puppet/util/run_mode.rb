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
        "$vardir/run"
      end

      def log_dir
        "$vardir/log"
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
        which_dir("/etc/puppet", "~/.puppet")
      end

      def var_dir
        which_dir("/var/lib/puppet", "~/.puppet/var")
      end
    end

    class WindowsRunMode < RunMode
      def conf_dir
        which_dir(File.join(windows_common_base("etc")), "~/.puppet")
      end

      def var_dir
        which_dir(File.join(windows_common_base("var")), "~/.puppet/var")
      end

    private

      def windows_common_base(*extra)
        [Dir::COMMON_APPDATA, "PuppetLabs", "puppet"] + extra
      end
    end
  end
end
