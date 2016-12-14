module Puppet
  module Acceptance
    module ModuleUtils

      # Return an array of module paths for a given host.
      #
      # Example return value:
      #
      # [
      #   "/etc/puppetlabs/code/environments/production/modules",
      #   "/etc/puppetlabs/code/modules",
      #   "/opt/puppet/share/puppet/modules",
      # ]
      #
      # @param host [String] hostname
      # @return [Array] paths for found modulepath
      def get_modulepaths_for_host (host)
        environment = on(host, puppet("config print environment")).stdout.chomp
        on(host, puppet("config print modulepath --environment #{environment}")).stdout.chomp.split(host['pathseparator'])
      end

      # Return a string of the default (first) path in modulepath for a given host.
      #
      # Example return value:
      #
      #   "/etc/puppetlabs/code/environments/production/modules"
      #
      # @param host [String] hostname
      # @return [String] first path for found modulepath
      def get_default_modulepath_for_host (host)
        get_modulepaths_for_host(host)[0]
      end

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
        on host, puppet("module list --render-as pson")
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
        ending_hash.each do |host, mod_array|
          mod_array.each do |mod|
            if ! beginning_hash[host].include? mod
              on host, "rm -rf '#{mod}'"
            end
          end
        end
      end

      # Convert a semantic version number string to an integer.
      #
      # Example return value given an input of '1.2.42':
      #
      #   10242
      #
      # @param semver [String] semantic version number
      def semver_to_i ( semver )
        # semver assumed to be in format <major>.<minor>.<patch>
        # calculation assumes that each segment is < 100
        tmp = semver.split('.')
        tmp[0].to_i * 10000 + tmp[1].to_i * 100 + tmp[2].to_i
      end

      # Compare two given semantic version numbers.
      #
      # Returns an integer indicating the relationship between the two:
      #   0 indicates that both are equal
      #   a value greater than 0 indicates that the semver1 is greater than semver2
      #   a value less than 0 indicates that the semver1 is less than semver2
      #
      def semver_cmp ( semver1, semver2 )
        semver_to_i(semver1) - semver_to_i(semver2)
      end

      # Assert that a module was installed according to the UI..
      #
      # This is a wrapper to centralize the validation about how
      # the UI responded that a module was installed.
      # It is called after a call # to `on ( host )` and inspects
      # STDOUT for specific content.
      #
      # @param stdout [String]
      # @param module_author [String] the author portion of a module name
      # @param module_name [String] the name portion of a module name
      # @param module_verion [String] the version of the module to compare to
      #     installed version
      # @param compare_op [String] the operator for comparing the verions of
      #     the installed module
      def assert_module_installed_ui ( stdout, module_author, module_name, module_version = nil, compare_op = nil )
        valid_compare_ops = {'==' => 'equal to', '>' => 'greater than', '<' => 'less than'}
        assert_match(/#{module_author}-#{module_name}/, stdout,
              "Notice that module '#{module_author}-#{module_name}' was installed was not displayed")
        if version
          /#{module_author}-#{module_name} \(.*v(\d+\.\d+\.\d+)/ =~ stdout
          installed_version = Regexp.last_match[1]
          if valid_compare_ops.include? compare_op
            assert_equal( true, semver_cmp(installed_version, module_version).send(compare_op, 0),
              "Installed version '#{installed_version}' of '#{module_name}' was not #{valid_compare_ops[compare_op]} '#{module_version}'")
          end
        end
      end

      # Assert that a module is installed on disk.
      #
      # @param host [HOST] the host object to make the remote call on
      # @param module_name [String] the name portion of a module name
      # @param optional moduledir [String, Array] the path where the module should be, will
      #        iterate over components of the modulepath by default.
      def assert_module_installed_on_disk (host, module_name, moduledir=nil)
        moduledir ||= get_modulepaths_for_host(host)
        modulepath = moduledir.is_a?(Array) ? moduledir : [moduledir]
        moduledir= nil

        modulepath.each do |i|
          # module directory should exist
          if on(host, %Q{[ -d "#{i}/#{module_name}" ]}, :acceptable_exit_codes => (0..255)).exit_code == 0
            moduledir = i
          end
        end
        fail_test('module directory not found') unless moduledir

        owner = ''
        group = ''
        on host, %Q{ls -ld "#{moduledir}"} do
          listing = stdout.split(' ')
          owner = listing[2]
          group = listing[3]
        end

        # A module's files should have:
        #     * a mode of 644 (755, if they're a directory)
        #     * owner == owner of moduledir
        #     * group == group of moduledir
        on host, %Q{ls -alR "#{moduledir}/#{module_name}"} do
          listings = stdout.split("\n")
          listings = listings.grep(/^[bcdlsp-]/)
          listings = listings.reject { |l| l =~ /\.\.$/ }

          listings.each do |line|
            fileinfo = parse_ls(line)
            assert_equal owner, fileinfo[:owner]
            assert_equal group, fileinfo[:group]

            if fileinfo[:filetype] == 'd'
              assert_equal 'rwx', fileinfo[:perms][:user]
              assert_equal 'r-x', fileinfo[:perms][:group]
              assert_equal 'r-x', fileinfo[:perms][:other]
            else
              assert_equal 'rw-', fileinfo[:perms][:user]
              assert_equal 'r--', fileinfo[:perms][:group]
              assert_equal 'r--', fileinfo[:perms][:other]
            end
          end
        end
      end

      LS_REGEX = %r[(.)(...)(...)(...).?[[:space:]]+\d+[[:space:]]+([[:word:]]+)[[:space:]]+([[:word:]]+).*[[:space:]]+([[:graph:]]+)$]

      def parse_ls(line)
        match = line.match(LS_REGEX)
        if match.nil?
          fail_test "#{line.inspect} doesn't match ls output regular expression"
        end

        captures = match.captures

        {
          :filetype => captures[0],
          :perms => {
            :user => captures[1],
            :group => captures[2],
            :other => captures[3],
          },
          :owner => captures[4],
          :group => captures[5],
          :file  => captures[6]
        }
      end
      private :parse_ls

      # Assert that a module is not installed on disk.
      #
      # @param host [HOST] the host object to make the remote call on
      # @param module_name [String] the name portion of a module name
      # @param optional moduledir [String, Array] the path where the module should be, will
      #        iterate over components of the modulepath by default.
      def assert_module_not_installed_on_disk (host, module_name, moduledir=nil)
        moduledir ||= get_modulepaths_for_host(host)
        modulepath = moduledir.is_a?(Array) ? moduledir : [moduledir]
        moduledir= nil

        modulepath.each do |i|
          # module directory should not exist
          on host, %Q{[ ! -d "#{i}/#{module_name}" ]}
        end
      end

      # Create a simple directory environment and puppet.conf at :tmpdir.
      #
      # @note Also registers a teardown block to remove generated files.
      #
      # @param tmpdir [String] directory to contain all the
      #   generated environment files
      # @return [String] path to the new puppet configuration file defining the
      #   environments
      def generate_base_directory_environments(tmpdir)
        puppet_conf = "#{tmpdir}/puppet2.conf"
        dir_envs = "#{tmpdir}/environments"

        step 'Configure a the direnv directory environment'
        apply_manifest_on master, %Q{
          File {
            ensure => directory,
            owner => #{master.puppet['user']},
            group => #{master.puppet['group']},
            mode => "0750",
          }
          file {
            [
              '#{dir_envs}',
              '#{dir_envs}/direnv',
            ]:
          }

          file {
            '#{puppet_conf}':
              ensure => file,
              content => "
                [main]
                environmentpath=#{dir_envs}
              "
          }
        }

        return puppet_conf
      end
    end
  end
end
