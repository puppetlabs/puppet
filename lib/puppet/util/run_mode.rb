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

      ##
      # Provide the full path of an override file to third parties in order to
      # allow them to easily override a default value for a specific puppet
      # installation.  The purpose of this API call is to provide one place
      # where override file pathes are constructed and expose the path to third
      # parties.
      #
      # @param [String] type The type of override to construct a path for, e.g.
      #   "confdir" or "vardir"
      #
      # @api public
      #
      # @return [String] the full path for the specified override file
      def self.override_path(type)
        File.join(File.dirname(__FILE__), "default_system_#{type}.override")
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
      # Return the path of an overriden default confdir
      #
      # @return [String, false] if there is an override return the string path.
      #   if there is no override return false.
      def system_confdir_override
        if @system_confdir_override.nil?
          @system_confdir_override = read_override("confdir")
        else
          @system_confdir_override
        end
      end

      ##
      # Return the path of an overriden default vardir
      #
      # @return [String, false] if there is an override return the string path.
      #   if there is no override return false.
      def system_vardir_override
        if @system_vardir_override.nil?
          @system_vardir_override = read_override("vardir")
        else
          @system_vardir_override
        end
      end

      ##
      # Read an override file if able or return false.  The file read is named
      # `"default_#{type}_dir"` in the same folder as this source file at
      # runtime.
      #
      # The contents of the file are expected to be a fully qualified path.
      # For example, "/etc/puppetlabs/puppet" or "/var/lib/operations/puppet"
      # for confdir and vardir respectively.
      #
      # @param [String] type The type of default override to read, e.g. "confdir"
      #   or "vardir"
      #
      # @return [String, false] if readable return the first line without the
      #   newline.  if not readable return false.
      def read_override(type)
        override_file = Pathname.new(self.class.override_path(type))
        if override_file.readable?
          File.open(override_file, 'r') {|f| f.readline.chomp}
        else
          false
        end
      end

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
          File.expand_path(user)
        end
      end
    end

    class UnixRunMode < RunMode
      def conf_dir
        system_conf_dir = system_confdir_override || "/etc/puppet"
        which_dir(system_conf_dir, "~/.puppet")
      end

      def var_dir
        system_var_dir = system_vardir_override || "/var/lib/puppet"
        which_dir(system_var_dir, "~/.puppet/var")
      end
    end

    class WindowsRunMode < RunMode
      def conf_dir
        if system_confdir_override
          system_conf_dir = system_confdir_override
        else
          system_conf_dir = File.join(windows_common_base("etc"))
        end
        which_dir(system_conf_dir, "~/.puppet")
      end

      def var_dir
        if system_vardir_override
          system_var_dir = system_vardir_override
        else
          system_var_dir = File.join(windows_common_base("var"))
        end
        which_dir(system_var_dir, "~/.puppet/var")
      end

    private

      def windows_common_base(*extra)
        [Dir::COMMON_APPDATA, "PuppetLabs", "puppet"] + extra
      end
    end
  end
end
