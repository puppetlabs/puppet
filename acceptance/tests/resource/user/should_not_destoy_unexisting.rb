test_name "making_sure that puppet does not report removing a user that does not exist"

name = "pl#{rand(999999).to_i}"

step "verify that user #{name} does not exist"
agents.each do |agent|
  agent.user_absent(name)
end

step "making_sure absent doesn't try and do anything"
on(agents, puppet_resource('user', name, 'making_sure=absent')) do
  fail_test "tried to remove the user, apparently" if stdout.include? 'removed'
end
