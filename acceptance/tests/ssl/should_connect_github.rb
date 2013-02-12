test_name "puppet should be able to authenticate the forge"

# See #11276
confine :except, :platform => 'windows'

agents.each do |agent|
  on(agent, puppet("module search stdlib"))
end
