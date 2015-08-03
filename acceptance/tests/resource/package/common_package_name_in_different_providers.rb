test_name "ticket 1073: common package name in two different providers should be allowed"

confine :to, {:platform => /(?:centos|el-|fedora)/}, agents

require 'puppet/acceptance/rpm_util'
extend Puppet::Acceptance::RpmUtils

rpm_options = {:pkg => 'guid', :version => '1.0'}

teardown do
  step "cleanup"
  agents.each do |agent|
    clean_rpm agent, rpm_options
  end
end

def verify_state(hosts, pkg, state, match)
  hosts.each do |agent|
    # Note yum lists packages as <name>.<arch>
    on agent, 'yum list installed' do
      method(match).call(/^#{pkg}\./, stdout)
    end

    on agent, 'gem list --local' do
      method(match).call(/^#{pkg} /, stdout)
    end
  end
end

def verify_present(hosts, pkg)
  verify_state(hosts, pkg, '(?!purged|absent)[^\']+', :assert_match)
end

def verify_absent(hosts, pkg)
  verify_state(hosts, pkg, '(?:purged|absent)', :assert_no_match)
end

# Setup repo and package
agents.each do |agent|
  clean_rpm agent, rpm_options
  setup_rpm agent, rpm_options
  send_rpm agent, rpm_options
end

verify_absent agents, 'guid'

# Test error trying to install duplicate packages
collide1_manifest = <<MANIFEST
  package {'guid': ensure => installed}
  package {'other-guid': name => 'guid', ensure => present}
MANIFEST

apply_manifest_on(agents, collide1_manifest, :acceptable_exit_codes => [1]).each do |result|
  assert_match(/Error while evaluating a Resource Statement, Cannot alias Package\[other-guid\] to \["guid", nil\]/, "#{result.host}: #{result.stderr}")
end

verify_absent agents, 'guid'

collide2_manifest = <<MANIFEST
  package {'guid': ensure => '0.1.0', provider => gem}
  package {'other-guid': name => 'guid', ensure => installed, provider => gem}
MANIFEST

apply_manifest_on(agents, collide2_manifest, :acceptable_exit_codes => [1]).each do |result|
  assert_match(/Error while evaluating a Resource Statement, Cannot alias Package\[other-guid\] to \["guid", "gem"\]/, "#{result.host}: #{result.stderr}")
end

verify_absent agents, 'guid'

# Test successful parallel installation
install_manifest = <<MANIFEST
  package {'guid': ensure => installed}

  package {'gem-guid':
    provider => gem,
    name => 'guid',
    ensure => installed,
  }
MANIFEST

apply_manifest_on(agents, install_manifest).each do |result|
  assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
  assert_match('Package[gem-guid]/ensure: created', "#{result.host}: #{result.stdout}")
end

verify_present agents, 'guid'

# Test removal
remove_manifest = <<MANIFEST
  package {'gem-guid':
    provider => gem,
    name => 'guid',
    ensure => absent,
  }

  package {'guid': ensure => absent}
MANIFEST

apply_manifest_on(agents, remove_manifest).each do |result|
  assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
  assert_match('Package[gem-guid]/ensure: removed', "#{result.host}: #{result.stdout}")
end

verify_absent agents, 'guid'

