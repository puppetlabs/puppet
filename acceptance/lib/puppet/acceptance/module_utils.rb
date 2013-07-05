module Puppet
  module Acceptance
    module ModuleUtils

      # Return an array of paths to installed modules for a given host.
      #
      # Example return value:
      #
      # [
      #   "/opt/puppet/share/puppet/modules/apt",
      #   "/opt/puppet/share/puppet/modules/auth_conf",
      #   "/opt/puppet/share/puppet/modules/concat",
      # ]
      #
      # @param host [String] hostname
      # @return [Array] paths for found modules
      def get_installed_modules_for_host (host)
        on host, puppet("module list --render-as s")
        str  = stdout.lines.to_a.last
        pat = /\(([^()]+)\)/
        mods =  str.scan(pat).flatten
        return mods
      end

      # Return a hash of array of paths to installed modules for a hosts.
      # The individual hostnames are the keys of the hash. The only value
      # for a given key is an array of paths for the found modules.
      #
      # Example return value:
      #
      # {
      #   "my_master" =>
      #     [
      #       "/opt/puppet/share/puppet/modules/apt",
      #       "/opt/puppet/share/puppet/modules/auth_conf",
      #       "/opt/puppet/share/puppet/modules/concat",
      #     ],
      #   "my_agent01" =>
      #     [
      #       "/opt/puppet/share/puppet/modules/apt",
      #       "/opt/puppet/share/puppet/modules/auth_conf",
      #       "/opt/puppet/share/puppet/modules/concat",
      #     ],
      # }
      #
      # @param hosts [Array] hostnames
      # @return [Hash] paths for found modules indexed by hostname
      def get_installed_modules_for_hosts (hosts)
        mods  = {}
        hosts.each do |host|
          mods[host] = get_installed_modules_for_host host
        end
        return mods
      end

      # Compare the module paths in given hashes and remove paths that
      # are were not present in the first hash. The use case for this
      # method is to remove any modules that were installed during the
      # course of a test run.
      #
      # Installed module hashes would be gathered using the
      # `get_+installed_module_for_hosts` command in the setup stage
      # and teardown stages of a test. These hashes would be passed into
      # this method in order to find modules installed during the test
      # and delete them in order to return the SUT environments to their
      # initial state.
      #
      # TODO: Enhance to take versions into account, so that upgrade/
      # downgrade events during a test does not persist in the SUT
      # environment.
      #
      # @param beginning_hash [Hash] paths for found modules indexed
      #   by hostname. Taken in the setup stage of a test.
      # @param ending_hash [Hash] paths for found modules indexed
      #   by hostname. Taken in the teardown stage of a test.
      def rm_installed_modules_from_hosts (beginning_hash, ending_hash)
        ending_hash.each do |host, mod_array|3
          mod_array.each do |mod|
            if ! beginning_hash[host].include? mod
              on host, "rm -rf #{mod}"
            end
          end
        end
      end

    end
  end
end
