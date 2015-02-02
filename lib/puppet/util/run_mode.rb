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

      def conf_dir
        "#{puppet_dir}/config"
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
      def puppet_dir
        which_dir("/etc/puppetlabs/agent", "~/.puppet")
      end

      def var_dir
        # If Puppet is run as a non-root user and vardir is specified via the commandline,
        # we'll need to use this user defined value when creating paths for rundir and logdir
        user_vardir = if Puppet[:vardir] then Puppet[:vardir] else "~/.puppet/var" end
        which_dir("/opt/puppetlabs/agent/cache", user_vardir)
      end

      def run_dir
        which_dir("/var/run/puppetlabs", File.join(var_dir, "run"))
      end

      def log_dir
        which_dir("/var/log/puppetlabs/agent", File.join(var_dir, "log"))
      end
    end

    class WindowsRunMode < RunMode
      def puppet_dir
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
