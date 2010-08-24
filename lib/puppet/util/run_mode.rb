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
          (Puppet.features.microsoft_windows? ? File.join(Dir::WINDOWS, "puppet", "etc") : "/etc/puppet"),
          "~/.puppet"
        )
      end

      def var_dir
        which_dir(
          (Puppet.features.microsoft_windows? ? File.join(Dir::WINDOWS, "puppet", "var") : "/var/lib/puppet"),
          "~/.puppet/var"
        )
      end

      def run_dir
        "$vardir/run"
      end

      def logopts
        if master?
          {
            :default => "$vardir/log",
            :mode    => 0750,
            :owner   => "service",
            :group   => "service",
            :desc    => "The Puppet log directory."
          }
        else
          ["$vardir/log", "The Puppet log directory."]
        end
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
