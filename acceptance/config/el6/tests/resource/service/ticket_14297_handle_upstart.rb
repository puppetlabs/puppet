test_name 'Upstart Testing'

# only run these on ubuntu vms
confine :to, :platform => 'ubuntu'

# pick any ubuntu agent
agent = agents.first

def check_service_for(pkg, type, agent)
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

begin
# in Precise these packages provide a mix of upstart with no linked init
# script (tty2), upstart linked to an init script (rsyslog), and no upstart
# script - only an init script (apache2)
  %w(tty2 rsyslog apache2).each do |pkg|
    on agent, puppet_resource("package #{pkg} ensure=present")

    step "Ensure #{pkg} has started"
    on agent, "service #{pkg} start", :acceptable_exit_codes => [0,1]

    step "Check that status for running #{pkg}"
    check_service_for(pkg, "start", agent)

    step "Stop #{pkg} with `puppet resource'"
    on agent, puppet_resource("service #{pkg} ensure=stopped")

    step "Check that status for stopped #{pkg}"
    check_service_for(pkg, "stop", agent)

    step "Start #{pkg} with `puppet resource'"
    on agent, puppet_resource("service #{pkg} ensure=running")

    step "Check that status for started #{pkg}"
    check_service_for(pkg, "start", agent)
  end

  on agent, puppet_resource("service") do
    assert_match(/service \{ 'ssh':\n.*  ensure => 'running',/, stdout, "SSH isn't running, something is wrong with upstart.")
  end
ensure
  on agent, puppet_resource("package apache2 ensure=absent")
end
