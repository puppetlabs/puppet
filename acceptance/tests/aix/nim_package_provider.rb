test_name "NIM package provider should work correctly"

tag 'audit:high',
    'audit:acceptance'  # OS specific by definition

# nim test is slow, confine to only aix 7.2 and recent puppet versions
confine :to, :platform => "aix" do |aix|
  version = on(aix, 'puppet --version').stdout
  version &&
    Gem::Version.new(version) > Gem::Version.new('6.4.0') &&
    on(aix, 'facter os.release.full').stdout == '7.2'
end

teardown do
    test_apply('cdrecord', 'absent', '')
    test_apply('puppet.test.rte', 'absent', '')
end

def assert_package_version(package, expected_version)
  # The output of lslpp is a colon-delimited list like:
  # sudo:sudo.rte:1.8.6.4: : :C: :Configurable super-user privileges runtime: : : : : : :0:0:/:
  # We want the version, so grab the third field
  on(hosts, "lslpp -qLc #{package} | cut -f3 -d:") do |result|
    actual_version = result.stdout.chomp
    assert_equal(expected_version, actual_version, "Installed package version #{actual_version} does not match expected version #{expected_version}")
  end
end

def get_manifest(package, ensure_value)
  <<MANIFEST
package {'#{package}':
  ensure   => '#{ensure_value}',
  source   => 'lpp_custom',
  provider => nim,
}
MANIFEST
end

def test_apply(package_name, ensure_value, expected_version)
  manifest = get_manifest(package_name, ensure_value)
  on hosts, puppet_apply(["--detailed-exitcodes", "--verbose"]),
     {:stdin => manifest, :acceptable_exit_codes => [2]}

  step "validate installed package version" do
    assert_package_version package_name, expected_version
  end

  step "run again to ensure idempotency" do
    on hosts, puppet_apply(["--detailed-exitcodes", "--verbose"]),
       {:stdin => manifest, :acceptable_exit_codes => [0]}
  end

  step "validate installed package version" do
    assert_package_version package_name, expected_version
  end
end

# These two packages live in an LPP source on the NIM master. Details
# on our nim masters are available at
# https://confluence.puppetlabs.com/display/OPS/IBM+Power+LPARs
package_types = {
    "RPM" => {
        :package_name    => "cdrecord",
        :old_version     => '1.9-6',
        :new_version     => '1.9-9'
    },
    "BFF" => {
        :package_name    => "puppet.test.rte",
        :old_version     => '1.0.0.0',
        :new_version     => '2.0.0.0'
    }
}

step "Setup: ensure test packages are not installed" do
  pkgs = ['cdrecord', 'puppet.test.rte']
  pkgs.each do |pkg|
    on hosts, puppet_apply(["--detailed-exitcodes", "--verbose"]),
       {:stdin => get_manifest(pkg, 'absent'), :acceptable_exit_codes => [0,2]}
  end
end

package_types.each do |package_type, details|
  step "install a #{package_type} package via 'ensure=>present'" do
    package_name = details[:package_name]
    version = details[:new_version]
    test_apply(package_name, 'present', version)
  end

  step "uninstall a #{package_type} package via 'ensure=>absent'" do
    package_name = details[:package_name]
    version = ''
    test_apply(package_name, 'absent', version)
  end

  step "install a #{package_type} package via 'ensure=><OLD_VERSION>'" do
    package_name = details[:package_name]
    version = details[:old_version]
    test_apply(package_name, version, version)
  end

  step "upgrade a #{package_type} package via 'ensure=><NEW_VERSION>'" do
    package_name = details[:package_name]
    version = details[:new_version]
    test_apply(package_name, version, version)
  end

  step "attempt to downgrade a #{package_type} package via 'ensure=><OLD_VERSION>'" do
    package_name = details[:package_name]
    version = details[:old_version]

    manifest = get_manifest(package_name, version)
    on(hosts, puppet_apply("--verbose", "--detailed-exitcodes"),
       { :stdin => manifest,
         :acceptable_exit_codes => [4,6] }) do |result|

        assert_match(/NIM package provider is unable to downgrade packages/, result.stderr, "Didn't get an error about downgrading packages")
    end
  end

end
