module Puppet
  module Acceptance
    module InstallUtils

      # Installs packages on the hosts.
      #
      # @param hosts [Array<Host>] Array of hosts to install packages to.
      # @param package_hash [Hash{Regexp=>Array<String,Array<String,String>>}]
      #   Keys should be regular expressions matching some desired subset of
      #   host['platform'].  Values should be an array of package names to
      #   install, or of two element arrays where a[0] is the command we expect
      #   to find on the platform and a[1] is the package name (when they are
      #   different).
      # @param options [Hash{Symbol=>Boolean}]
      # @option options [Boolean] :check_if_exists First check to see if
      #   command is present before installing package.  (Default false)
      # @return true
      def self.install_packages_on(hosts, package_hash, options = {})
        check_if_exists = options[:check_if_exists]
        hosts = [hosts] unless hosts.kind_of?(Array)
        hosts.each do |host|
          package_hash.each do |regex,package_list|
            if regex.match(host['platform'])
              package_list.each do |cmd_pkg|
                if cmd_pkg.kind_of?(Array)
                  command, package = cmd_pkg
                else
                  command = package = cmd_pkg
                end
                if !check_if_exists || !host.check_for_package(command)
                  host.logger.notify("Installing #{package}")
                  host.install_package(package)
                end
              end
            end
          end
        end
        return true
      end

    end
  end
end
