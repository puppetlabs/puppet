test_name "aix package provider should work correctly"

confine :to, :platform => /aix/

dir = "/tmp/aix-packages-#{$$}"

teardown do
  on hosts, "rm -rf #{dir}"
end

def assert_package_version(package, expected_version)
  # The output of lslpp is a colon-delimited list like:
  # sudo:sudo.rte:1.8.6.4: : :C: :Configurable super-user privileges runtime: : : : : : :0:0:/:
  # We want the version, so grab the third field
  on hosts, "lslpp -qLc #{package} | cut -f3 -d:" do
    actual_version = stdout.chomp
    assert_equal(expected_version, actual_version, "Installed package version #{actual_version} does not match expected version #{expected_version}")
  end
end

package = 'sudo.rte'
version1 = '1.7.10.4'
version2 = '1.8.6.4'

step "download packages to use for test"

on hosts, "mkdir -p #{dir}"
on hosts, "curl neptune.puppetlabs.lan/misc/sudo.#{version1}.aix51.lam.bff > #{dir}/sudo.#{version1}.aix51.lam.bff"
on hosts, "curl neptune.puppetlabs.lan/misc/sudo.#{version2}.aix51.lam.bff > #{dir}/sudo.#{version2}.aix51.lam.bff"

step "setup manifests for testing"

version1_manifest = <<-MANIFEST
package { '#{package}':
  ensure   => '#{version1}',
  provider => aix,
  source   => '#{dir}',
}
MANIFEST

version2_manifest = <<-MANIFEST
package { '#{package}':
  ensure   => '#{version2}',
  provider => aix,
  source   => '#{dir}',
}
MANIFEST

absent_manifest = <<-MANIFEST
package { '#{package}':
  ensure   => absent,
  provider => aix,
  source   => '#{dir}',
}
MANIFEST

step "install the package"

apply_manifest_on hosts, version1_manifest

step "verify package is installed and at the correct version"

assert_package_version package, version1

step "install a newer version of the package"

apply_manifest_on hosts, version2_manifest

step "verify package is installed and at the newer version"

assert_package_version package, version2

step "test that downgrading fails by trying to install an older version of the package"

on hosts, puppet_apply("--verbose", "--detailed-exitcodes"), :stdin => version1_manifest, :acceptable_exit_codes => [4,6] do
  assert_match(/aix package provider is unable to downgrade packages/, stdout, "Didn't get an error about downgrading packages")
end

step "uninstall the package"

apply_manifest_on hosts, absent_manifest

step "verify the package is gone"

on hosts, "lslpp -qLc #{package}", :acceptable_exit_codes => [1]
