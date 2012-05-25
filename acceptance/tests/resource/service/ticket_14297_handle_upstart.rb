test_name 'Upstart Testing'

# only run these on ubuntu vms
confine :to, :platform => 'ubuntu'

# pick any ubuntu agent
agent = agents.first

def check_service_for(pkg, type)
  if pkg == "apache2"
    if type == "stop"
      on agent, "service #{pkg} status", :acceptable_exit_codes => [1,2,3]
    else
      on agent, "service #{pkg} status", :acceptable_exit_codes => [0]
    end
  else
    on agent, "service #{pkg} status | grep #{type} -q"
  end
end

# in Precise these packages provide a mix of upstart with no linked init
# script (tty1), upstart linked to an init script (rsyslog), and no upstart
# script - only an init script (apache2)
%w(tty1 rsyslog apache2).each do |pkg|
  on agent, puppet_resource("package #{pkg} ensure=present")

  step "Ensure #{pkg} has started"
  on agent, "service #{pkg} start", :acceptable_exit_codes => [0,1]

  step "Check that status for running #{pkg}"
  check_service_for(pkg, "start")

  step "Stop #{pkg} with `puppet resource'"
  on agent, puppet_resource("service #{pkg} ensure=stopped")

  step "Check that status for stopped #{pkg}"
  check_service_for(pkg, "stop")

  step "Start #{pkg} with `puppet resource'"
  on agent, puppet_resource("service #{pkg} ensure=running")

  step "Check that status for started #{pkg}"
  check_service_for(pkg, "start")

  on agent, puppet_resource("package #{pkg} ensure=absent")
end
