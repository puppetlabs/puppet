test_name 'PUP-2630 ensure $server_facts is set and warning is issued if any value is overwritten by an agent'

step 'ensure :trusted_server_facts is false by default'
on(master, puppet('master', '--configprint trusted_server_facts')) do |result|
  assert_match('false', result.stdout,
               'trusted_server_facts setting should be false by default')
end

step 'ensure $server_facts does not exist by default'
testdir = master.tmpdir(File.basename(__FILE__, ".*"))

test_manifest = <<MANIFEST
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}
file {
  '#{testdir}':;
  '#{testdir}/environments':;
  '#{testdir}/environments/production':;
  '#{testdir}/environments/production/modules':;
  '#{testdir}/environments/production/manifests':;
}

file { '#{testdir}/environments/production/manifests/site.pp':
  ensure  => file,
  content => 'notify{"abc$server_facts":}
  ',
}
MANIFEST

apply_manifest_on(master, test_manifest)

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  }
}
with_puppet_running_on(master, master_opts) do
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master}"),
       :acceptable_exit_codes => 2) do |result|
      assert_match(/as 'abc'/, result.stdout,
                   "#{agent}: $server_facts should be empty prior to opt-in" )
    end
  end
end

step 'ensure $server_facts DO exist after the user opts-in'
master_opts['main']['trusted_server_facts'] = true
with_puppet_running_on(master, master_opts) do
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master}"),
       :acceptable_exit_codes => 2) do |result|
      assert_match(/abc{serverversion/, result.stdout,
                   "#{agent}: $server_facts should have some stuff" )
    end
  end

  step 'ensure puppet issues a warning if an agent overwrites a server fact'
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master}",
                     'ENV' => { 'FACTER_server_facts' => 'overwrite' }),
      :acceptable_exit_codes => 1) do |result|
      assert_match(/Attempt to assign to a reserved variable name: 'server_facts'/,
                   result.stderr, "#{agent}: $server_facts should warn if overwritten" )
    end
  end
end
