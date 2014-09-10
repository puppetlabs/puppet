# User story:
# A new user has installed puppet either from source or from a gem, which does
# not put the "puppet" user or group on the system. They run the puppet master,
# which fails because of the missing user and then correct their actions. They
# expect that after correcting their actions, puppet will work correctly.
test_name "Puppet manages its own configuration in a robust manner"

skip_test "JVM Puppet cannot change its user while running." if @options[:is_puppetserver]

# when owner/group works on windows for settings, this confine should be removed.
confine :except, :platform => 'windows'
# when managhome roundtrips for solaris, this confine should be removed
confine :except, :platform => 'solaris'
# pe setup includes ownership of external directories such as the passenger
# document root, which puppet itself knows nothing about
confine :except, :type => 'pe'
# same issue for a foss passenger run
if master.is_using_passenger?
  skip_test 'Cannot test with passenger.'
end

if master.use_service_scripts?
  # Beaker defaults to leaving puppet running when using service scripts,
  # Need to shut it down so we can modify user/group and test startup failure
  on(master, puppet('resource', 'service', master['puppetservice'], 'ensure=stopped'))
end

step "Clear out yaml directory because of a bug in the indirector/yaml. (See #21145)"
on master, 'rm -rf $(puppet master --configprint yamldir)'

original_state = {}
step "Record original state of system users" do
  hosts.each do |host|
    original_state[host] = {}
    original_state[host][:user] = user = host.execute('puppet config print user')
    original_state[host][:group] = group = host.execute('puppet config print group')
    original_state[host][:ug_resources] = on(host, puppet('resource', 'user', user)).stdout
    original_state[host][:ug_resources] += on(host, puppet('resource', 'group', group)).stdout
    original_state[host][:ug_resources] += "Group['#{group}'] -> User['#{user}']\n"
  end
end

teardown do
  # And cleaning up yaml dir again here because we are changing service
  # user and group ids back to the original uid and gid
  on master, 'rm -rf $(puppet master --configprint yamldir)'

  hosts.each do |host|
    apply_manifest_on(host, <<-ORIG)
      #{original_state[host][:ug_resources]}
    ORIG
  end

  with_puppet_running_on(master, {}) do
    agents.each do |agent|
      on agent, puppet('agent', '-t', '--server', master)
    end
  end
end

step "Remove system users" do
  hosts.each do |host|
    on host, puppet('resource', 'user', original_state[host][:user], 'ensure=absent')
    on host, puppet('resource', 'group', original_state[host][:group], 'ensure=absent')
  end
end

step "Ensure master fails to start when missing system user" do
  on master, puppet('master'), :acceptable_exit_codes => [74] do
    assert_match(/could not change to group "#{original_state[master][:group]}"/, result.output)
    assert_match(/Could not change to user #{original_state[master][:user]}/, result.output)
  end
end

step "Ensure master starts when making users after having previously failed startup" do
  with_puppet_running_on(master,
                         :master => { :mkusers => true }) do
    agents.each do |agent|
      on agent, puppet('agent', '-t', '--server', master)
    end
  end
end
