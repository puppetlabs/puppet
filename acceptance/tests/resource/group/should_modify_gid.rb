test_name "should modify gid of existing group"
confine :except, :platform => 'windows'

name = "pl#{rand(999999).to_i}"
gid1  = rand(999999).to_i
gid2  = rand(999999).to_i

agents.each do |agent|
  step "ensure that the group exists with gid #{gid1}"
  on(agent, puppet_resource('group', name, 'ensure=present', "gid=#{gid1}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid1}'/
  end

  step "ensure that we can modify the GID of the group to #{gid2}"
  on(agent, puppet_resource('group', name, 'ensure=present', "gid=#{gid2}")) do
    fail_test "missing gid notice" unless stdout =~ /gid +=> +'#{gid2}'/
  end

  step "verify that the GID changed"
  on(agent, "getent group #{name}") do
    fail_test "gid is wrong through getent output" unless
      stdout =~ /^#{name}:.*:#{gid2}:/
  end

  step "clean up the system after the test run"
  on(agent, puppet_resource('group', name, 'ensure=absent'))
end
