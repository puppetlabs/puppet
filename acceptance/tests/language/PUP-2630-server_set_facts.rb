test_name 'PUP-2630, PUP-6112 ensure $server_facts is set and warning is issued if any value is overwritten by an agent'

step 'ensure :trusted_server_facts is true by default'
on(master, puppet('master', '--configprint trusted_server_facts')) do |result|
  assert_match('true', result.stdout,
               'trusted_server_facts setting should be true by default')
end

step 'ensure $server_facts exist'
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
