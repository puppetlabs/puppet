require 'etc'
require 'fileutils'

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
        if Puppet.features.root?
          File.expand_path(system)
        else
          # Starting with puppet 4 and AIO packaging, AIO introduced new paths for
          # both root and non-root users. The paths used by the root user are created
          # by packaging, so no special action is required in the code.
          #
          # However, for non-root users, these new paths introduce deep paths (see below
          # in the two RunMode sub-classes). Since puppet doesn't create parent directories
          # for directories in the settings catalog, we take this opportunity to create
          # those parent directories. (Note that pre-AIO this code would have had to do the
          # same thing, except that everything was under ~/.puppet which was confdir so was
          # created.)
          expanded_user = File.expand_path(user)
          FileUtils.mkdir_p(File.dirname(expanded_user)) if File.exists?(File.expand_path('~'))
          expanded_user
        end
      end
    end

    class UnixRunMode < RunMode
      def conf_dir
        which_dir("/etc/puppetlabs/puppet", "~/.puppetlabs/etc/puppet")
      end

      def code_dir
        which_dir("/etc/puppetlabs/code", "~/.puppetlabs/etc/code")
      end

      def var_dir
        which_dir("/opt/puppetlabs/puppet/cache", "~/.puppetlabs/opt/puppet/cache")
      end

      def run_dir
        which_dir("/var/run/puppetlabs", "~/.puppetlabs/var/run")
      end

      def log_dir
        which_dir("/var/log/puppetlabs/puppet", "~/.puppetlabs/var/log")
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

      def run_dir
        which_dir(File.join(windows_common_base("puppet/var/run")), "~/.puppetlabs/var/run")
      end

      def log_dir
        which_dir(File.join(windows_common_base("puppet/var/log")), "~/.puppetlabs/var/log")
      end

    private

      def windows_common_base(*extra)
        [Dir::COMMON_APPDATA, "PuppetLabs"] + extra
      end
    end
  end
end
