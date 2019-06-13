test_name "puppet device is able to run and configure a node"

tag 'server'

teardown do
  # revert permission changes to reset state for other tests
  on(master, "puppet agent -t --server #{master}")
end

step "Configure master for device runs"
on(master, "puppet config set server $(hostname --fqdn)")

codedir = "#{master.puppet['codedir']}/modules"
confdir = master.puppet['confdir']

on(master, puppet("module install --target-dir #{codedir} puppetlabs-test_device"))
on(master, puppet("module install --target-dir #{codedir} puppetlabs-device_manager"))
on(master, puppet("module install --target-dir #{codedir} puppetlabs-resource_api"))

apply_manifest_on(master, <<~MANIFEST, :catch_failures => true)
# create and configure test user to trigger PUP-9642
user {
  'test':
    ensure => 'present',
}

# testfile for --apply
file {
  '/tmp/spinner.pp':
    content => "spinner { '999': ensure => 'absent' }"
}

# install and configure the Resource API
include 'resource_api::server', 'resource_api::agent'
MANIFEST

on(master, "echo \"#{<<~CONF}\" >> #{confdir}/puppet.conf")
[main]
user = test
CONF

# configure device credentials
on(master, puppet("apply -e 'device_manager { [\"spinny1.example.com\", \"spinny2.example.com\", \"spinny3.example.com\"]: type => 'spinner', credentials => { facts_cpu_time => 1 }, include_module => false }'"))

with_puppet_running_on(master, {}) do
  device_command="umask 077; puppet device --debug --trace -w0"

  step "run operation without certificate"
  on(master, "#{device_command} --target spinny1.example.com --facts")

  step "request cert, or fall through"
  on(master, "#{device_command} --target spinny1.example.com", acceptable_exit_codes: [0, 1]) do |result|
    assert_no_match(/Permission denied/, result.stderr, 'cert requesting failed')
  end

  on(master, "umask 077; puppetserver ca sign --certname spinny1.example.com")

  step "test catalog application"
  on(master, "#{device_command} --target spinny1.example.com")

  step "test --resource"
  on(master, "#{device_command} --target spinny1.example.com --resource spinner")

  step "test --apply"
  on(master, "#{device_command} --target spinny1.example.com --apply /tmp/spinner.pp")

  step "test development runmode"
  device_command += " --libdir #{codedir}/test_device/lib"
  on(master, "#{device_command} --target spinny2.example.com --facts")
  on(master, "#{device_command} --target spinny2.example.com", acceptable_exit_codes: [0, 1]) do |result|
    assert_no_match(/Permission denied/, result.stderr, 'cert requesting failed with --libdir')
  end
  on(master, "umask 077; puppetserver ca sign --certname spinny2.example.com")
  on(master, "#{device_command} --target spinny2.example.com")
end
