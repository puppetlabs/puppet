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

      def which_dir( global, user )
        #FIXME: we should test if we're user "puppet"
        #       there's a comment that suggests that we do that
        #       and we currently don't.
        File.expand_path(if in_global_context? then global else user end)
      end

      def in_global_context?
        name == :master || Puppet.features.root?
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
        which_dir(File.join(windows_common_base("etc")), File.join(*windows_local_base))
      end

      def var_dir
        which_dir(File.join(windows_common_base("var")), File.join(*windows_local_base("var")))
      end

    private

      def windows_common_base(*extra)
        [Dir::COMMON_APPDATA, "PuppetLabs", "puppet"] + extra
      end

      def windows_local_base(*extra)
        [Dir::LOCAL_APPDATA, "PuppetLabs", "puppet"] + extra
      end
    end
  end
end
