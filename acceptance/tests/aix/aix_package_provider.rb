test_name "aix package provider should work correctly" do

  tag 'audit:medium',
      'audit:acceptance'  # OS specific by definition.

  confine :to, :platform => /aix/

  dir = "/tmp/aix-packages-#{$$}"

  def assert_package_version(package, expected_version)
    # The output of lslpp is a colon-delimited list like:
    # sudo:sudo.rte:1.8.6.4: : :C: :Configurable super-user privileges runtime: : : : : : :0:0:/:
    # We want the version, so grab the third field
    on hosts, "lslpp -qLc #{package} | cut -f3 -d:" do
      actual_version = stdout.chomp
      assert_equal(expected_version, actual_version, "Installed package version #{actual_version} does not match expected version #{expected_version}")
    end
  end

  def get_package_manifest(package, version, sourcedir)
    manifest = <<-MANIFEST
    package { '#{package}':
      ensure   => '#{version}',
      provider => aix,
      source   => '#{sourcedir}',
    }
    MANIFEST
  end

  package = 'sudo.rte'
  version1 = '1.7.10.4'
  version2 = '1.8.6.4'

  teardown do
    on hosts, "rm -rf #{dir}"
    on hosts, "installp -u #{package}"
  end

  step "download packages to use for test" do
    on hosts, "mkdir -p #{dir}"
    on hosts, "curl neptune.puppetlabs.lan/misc/sudo.#{version1}.aix51.lam.bff > #{dir}/sudo.#{version1}.aix51.lam.bff"
    on hosts, "curl neptune.puppetlabs.lan/misc/sudo.#{version2}.aix51.lam.bff > #{dir}/sudo.#{version2}.aix51.lam.bff"
  end

  step "install the older version of package" do
    apply_manifest_on(hosts, get_package_manifest(package, version1, dir), :catch_failures => true)
  end

  step "verify package is installed and at the correct version" do
    assert_package_version package, version1
  end

  step "install a newer version of the package" do
    apply_manifest_on(hosts, get_package_manifest(package, version2, dir), :catch_failures => true)
  end

  step "verify package is installed and at the newer version" do
    assert_package_version package, version2
  end

  step "test that downgrading fails by trying to install an older version of the package" do
    apply_manifest_on(hosts, get_package_manifest(package, version1, dir), :acceptable_exit_codes => [4,6]) do |res|
      assert_match(/aix package provider is unable to downgrade packages/, res.stderr, "Didn't get an error about downgrading packages")
    end
  end

  step "uninstall the package" do
    apply_manifest_on(hosts, get_package_manifest(package, 'absent', dir), :catch_failures => true)
  end

  step "verify the package is gone" do
    on hosts, "lslpp -qLc #{package}", :acceptable_exit_codes => [1]
  end

  step "install the older version of package" do
    apply_manifest_on(hosts, get_package_manifest(package, version1, dir), :catch_failures => true)
  end

  step "verify package is installed and at the correct version" do
    assert_package_version package, version1
  end

  step "install latest version of the package" do
    apply_manifest_on(hosts, get_package_manifest(package, 'latest', dir), :catch_failures => true)
  end

  step "verify package is installed and at the correct version" do
    assert_package_version package, version2
  end

  step "PUP-7818 remove a package without defining the source metaparameter" do
    manifest = get_package_manifest(package, 'latest', dir)
    manifest = manifest + "package { 'nonexistant_example_package.rte': ensure => absent, }"
    apply_manifest_on(hosts, manifest, :catch_failures => true)
  end

end
