require 'open-uri'
require 'open3'
require 'uri'
require 'puppet/acceptance/common_utils'

module Puppet
  module Acceptance
    module InstallUtils
      PLATFORM_PATTERNS = {
        :redhat        => /fedora|el-|centos/,
        :debian        => /debian|ubuntu|cumulus/,
        :debian_ruby18 => /debian|ubuntu-lucid|ubuntu-precise/,
        :solaris_10    => /solaris-10/,
        :solaris_11    => /solaris-11/,
        :windows       => /windows/,
        :eos           => /^eos-/,
      }.freeze

      # Installs packages on the hosts.
      #
      # @param hosts [Array<Host>] Array of hosts to install packages to.
      # @param package_hash [Hash{Symbol=>Array<String,Array<String,String>>}]
      #   Keys should be a symbol for a platform in PLATFORM_PATTERNS.  Values
      #   should be an array of package names to install, or of two element
      #   arrays where a[0] is the command we expect to find on the platform
      #   and a[1] is the package name (when they are different).
      # @param options [Hash{Symbol=>Boolean}]
      # @option options [Boolean] :check_if_exists First check to see if
      #   command is present before installing package.  (Default false)
      # @return true
      def install_packages_on(hosts, package_hash, options = {})
        check_if_exists = options[:check_if_exists]
        hosts = [hosts] unless hosts.kind_of?(Array)
        hosts.each do |host|
          package_hash.each do |platform_key,package_list|
            if pattern = PLATFORM_PATTERNS[platform_key]
              if pattern.match(host['platform'])
                package_list.each do |cmd_pkg|
                  if cmd_pkg.kind_of?(Array)
                    command, package = cmd_pkg
                  else
                    command = package = cmd_pkg
                  end
                  if !check_if_exists || !host.check_for_package(command)
                    host.logger.notify("Installing #{package}")
                    additional_switches = '--allow-unauthenticated' if platform_key == :debian
                    host.install_package(package, additional_switches)
                  end
                end
              end
            else
              raise("Unknown platform '#{platform_key}' in package_hash")
            end
          end
        end
        return true
      end

      # Configures gem sources on hosts to use a mirror, if specified
      # This is a duplicate of the Gemfile logic.
      def configure_gem_mirror(hosts)
        hosts = [hosts] unless hosts.kind_of?(Array)
        gem_source = ENV['GEM_SOURCE'] || 'https://rubygems.org'

        hosts.each do |host|
          gem = Puppet::Acceptance::CommandUtils.gem_command(host)
          on host, "#{gem} source --clear-all"
          on host, "#{gem} source --add #{gem_source}"
        end
      end
    end
  end
end
