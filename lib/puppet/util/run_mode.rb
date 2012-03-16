module Puppet
  module Util
    class RunMode
      def initialize(name)
        @name = name.to_sym
      end

      @@run_modes = Hash.new {|h, k| h[k] = RunMode.new(k)}

      attr :name

      def self.[](name)
        @@run_modes[name]
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


      def conf_dir
        which_dir(
            Puppet::Util::Settings.default_global_config_dir,
            Puppet::Util::Settings.default_user_config_dir
        )
      end

      def var_dir
        which_dir(
            Puppet::Util::Settings.default_global_var_dir,
            Puppet::Util::Settings.default_user_var_dir
        )
      end

      def run_dir
        "$vardir/run"
      end

      #def logopts
        # TODO cprice: need to look into how to get this into the catalog during a "use", because
        #  these are not getting set as "defaults" any more.  Best options are probably:
        #   1. special-case this during "initialize_application_defaults" in settings.rb,
        #   2. Allow :application_defaults settings category to carry these hashes with them somehow,
        #   3. delay the original call to define_settings for the application settings,
        #   4. make a second (override) call to "define_settings" during initialize_application_defaults
        #if master?
        #  {
        #    :default => "$vardir/log",
        #    :mode    => 0750,
        #    :owner   => "service",
        #    :group   => "service",
        #    :desc    => "The Puppet log directory."
        #  }
        #else
        #  ["$vardir/log", "The Puppet log directory."]
        #end
      #end

      def log_dir
        "$vardir/log"
      end

      private

      def which_dir( global, user )
        #FIXME: we should test if we're user "puppet"
        #       there's a comment that suggests that we do that
        #       and we currently don't.
        expand_path case
          when name == :master; global
          when Puppet.features.root?; global
          else user
        end
      end

      def expand_path( dir )
        require 'etc'
        ENV["HOME"] ||= Etc.getpwuid(Process.uid).dir
        File.expand_path(dir)
      end

    end
  end
end
