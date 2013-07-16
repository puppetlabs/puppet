# User story:
# A new user has installed puppet either from source or from a gem, which does
# not put the "puppet" user or group on the system. They run the puppet master,
# which fails because of the missing user and then correct their actions. They
# expect that after correcting their actions, puppet will work correctly.
test_name "Puppet manages its own configuration in a robust manner"

# when owner/group works on windows for settings, this confine should be removed.
confine :except, :platform => 'windows'
# when managhome roundtrips for solaris, this confine should be removed
confine :except, :platform => 'solaris'

step "Clear out yaml directory because of a bug in the indirector/yaml. (See #21145)"
on master, 'rm -rf $(puppet master --configprint yamldir)'

step "Record original state of system users"
original_state = {}
hosts.each do |host|
  original_state[host] = on(host, puppet('resource', 'user', 'puppet')).output
  original_state[host] += on(host, puppet('resource', 'group', 'puppet')).output
end

step "Remove system users"
hosts.each do |host|
  on host, puppet('resource', 'user', 'puppet', 'ensure=absent')
  on host, puppet('resource', 'group', 'puppet', 'ensure=absent')
end

step "Ensure master fails to start when missing system user"
on master, puppet('master'), :acceptable_exit_codes => [74] do
  assert_match(/could not change to group "puppet"/, result.output)
  assert_match(/Could not change to user puppet/, result.output)
end

step "Ensure master starts when making users after having previously failed startup"
with_master_running_on(master, '--mkusers --autosign true') do
  agents.each do |agent|
    on agent, puppet_agent('-t', '--server', master)
  end
end

teardown do
  # And cleaning up yaml dir again here because we are changing service
  # user and group ids back to the original uid and gid
  on master, 'rm -rf $(puppet master --configprint yamldir)'

  hosts.each do |host|
    apply_manifest_on(host, <<-ORIG)
      #{original_state[host]}
      Group['puppet'] -> User['puppet']
    ORIG
  end
end
