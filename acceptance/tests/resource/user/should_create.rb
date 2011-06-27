test_name "should create a user, and the default matching group"

name = "pl#{rand(999999).to_i}"

step "ensure that the user and group #{name} do not exist"
on agents, "if getent passwd #{name}; then userdel #{name}; fi"
on agents, "if getent group #{name}; then groupdel #{name}; fi"

step "ask puppet to create the user"
on(agents, puppet_resource('user', name, 'ensure=present'))

step "verify that the user and group now exist"
agents.each do |agent|
  if agent['platform'].include? 'sles' or agent['platform'].include? 'solaris'  # no private user groups by default
    on agent, "getent passwd #{name}"
  else
    on agent, "getent passwd #{name} && getent group #{name}"
  end
end


step "ensure that the user and group #{name} do not exist"
on agents, "if getent passwd #{name}; then userdel #{name}; fi"
on agents, "if getent group #{name}; then groupdel #{name}; fi"
