test_name "test the yum package provider"

confine :to, {:platform => /(?:centos|el-|fedora)/}, agents
confine :except, {:platform => /centos-4|el-4/}, agents # PUP-5227

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
  end
end

def verify_present(hosts, pkg)
  verify_state(hosts, pkg, '(?!purged|absent)[^\']+', :assert_match)
end

def verify_absent(hosts, pkg)
  verify_state(hosts, pkg, '(?:purged|absent)', :assert_no_match)
end

step 'Setup repo and package'
agents.each do |agent|
  clean_rpm agent, rpm_options
  setup_rpm agent, rpm_options
  send_rpm agent, rpm_options
end

step 'Installing a known package succeeds'
verify_absent agents, 'guid'
apply_manifest_on(agents, 'package {"guid": ensure => installed}').each do |result|
  assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
end

step 'Removing a known package succeeds'
verify_present agents, 'guid'
apply_manifest_on(agents, 'package {"guid": ensure => absent}').each do |result|
  assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
end

step 'Installing a specific version of a known package succeeds'
verify_absent agents, 'guid'
apply_manifest_on(agents, 'package {"guid": ensure => "1.0"}').each do |result|
  assert_match('Package[guid]/ensure: created', "#{result.host}: #{result.stdout}")
end

step 'Removing a specific version of a known package succeeds'
verify_present agents, 'guid'
apply_manifest_on(agents, 'package {"guid": ensure => absent}').each do |result|
  assert_match('Package[guid]/ensure: removed', "#{result.host}: #{result.stdout}")
end

step 'Installing a non-existant version of a known package fails'
verify_absent agents, 'guid'
apply_manifest_on(agents, 'package {"guid": ensure => "1.1"}').each do |result|
  assert_not_match(/Package\[guid\]\/ensure: created/, "#{result.host}: #{result.stdout}")
  assert_match('Package[guid]/ensure: change from purged to 1.1 failed', "#{result.host}: #{result.stderr}")
end
verify_absent agents, 'guid'

step 'Installing a non-existant package fails'
verify_absent agents, 'not_a_package'
apply_manifest_on(agents, 'package {"not_a_package": ensure => present}').each do |result|
  assert_not_match(/Package\[not_a_package\]\/ensure: created/, "#{result.host}: #{result.stdout}")
  assert_match('Package[not_a_package]/ensure: change from purged to present failed', "#{result.host}: #{result.stderr}")
end
verify_absent agents, 'not_a_package'

step 'Removing a non-existant package succeeds'
verify_absent agents, 'not_a_package'
apply_manifest_on(agents, 'package {"not_a_package": ensure => absent}').each do |result|
  assert_not_match(/Package\[not_a_package\]\/ensure/, "#{result.host}: #{result.stdout}")
  assert_match('Applied catalog', "#{result.host}: #{result.stdout}")
end
verify_absent agents, 'not_a_package'

