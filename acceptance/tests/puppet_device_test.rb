test_name "puppet device is able to run and configure a node"

teardown do
  on(master, "[ -f /etc/puppetlabs/puppet/puppet.conf.bak ] && mv /etc/puppetlabs/puppet/puppet.conf.bak /etc/puppetlabs/puppet/puppet.conf")
  # revert permission changes to reset state for other tests
  on(master, "puppet agent -t --server #{master}")
end

# set sensible defaults
on(master, "cp /etc/puppetlabs/puppet/puppet.conf /etc/puppetlabs/puppet/puppet.conf.bak")
on(master, "puppet config set server $(hostname --fqdn)")

codedir = "#{master.puppet['codedir']}/modules"
confdir = master.puppet['confdir']
common_options="--config /tmp/puppet.conf --debug --trace -w0"

on(master, puppet("module install --target-dir #{codedir} puppetlabs-test_device"))
on(master, puppet("module install --target-dir #{codedir} puppetlabs-device_manager"))
on(master, puppet("module install --target-dir #{codedir} puppetlabs-resource_api"))

apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
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
service { 'puppetserver': }
include 'resource_api::server', 'resource_api::agent'
MANIFEST

on(master, "cp -v #{confdir}/puppet.conf /tmp/puppet.conf")
on(master, "echo \"#{<<-CONF}\" >> /tmp/puppet.conf")
[main]
user = test
CONF

# configure device credentials
on(master, puppet("apply -e 'device_manager { [\"spinny1.example.com\", \"spinny2.example.com\", \"spinny3.example.com\"]: type => 'spinner', credentials => { facts_cpu_time => 1 }, include_module => false }'"))

# run operation without certificate
on(master, "umask 077; puppet device #{common_options} --target spinny1.example.com --facts")

# request cert, or fall through
on(master, "umask 077; puppet device #{common_options} --target spinny1.example.com", acceptable_exit_codes: [0, 1]) do |result|
  assert_no_match(/Permission denied/, result.stderr, 'cert requesting failed')
end

on(master, "umask 077; puppetserver ca sign --certname spinny1.example.com")

# test catalog application
on(master, "umask 077; puppet device #{common_options} --target spinny1.example.com")

# test --resource
on(master, "umask 077; puppet device  #{common_options} --target spinny1.example.com --resource spinner")

# test --apply
on(master, "umask 077; puppet device  #{common_options} --target spinny1.example.com --apply /tmp/spinner.pp")

# test development runmode
common_options += " --libdir #{codedir}/test_device/lib"
on(master, "umask 077; puppet device #{common_options} --target spinny2.example.com --facts")
on(master, "umask 077; puppet device #{common_options} --target spinny2.example.com", acceptable_exit_codes: [0, 1]) do |result|
  assert_no_match(/Permission denied/, result.stderr, 'cert requesting failed with --libdir')
end
on(master, "umask 077; puppetserver ca sign --certname spinny2.example.com")
on(master, "umask 077; puppet device #{common_options} --target spinny2.example.com")
