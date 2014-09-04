test_name 'Upstart Testing'

# only run these on ubuntu vms
confine :to, :platform => 'ubuntu'

# pick any ubuntu agent
agent = agents.first

def check_service_for(pkg, type, agent)
  on agent, puppet_resource("service", "#{pkg}") do
    assert_match(/ensure => '#{type}'/, stdout, "Expect #{pkg} to be #{type}")
  end
end

def manage_service_for(pkg, state, agent)

  manifest = <<-MANIFEST
    service { '#{pkg}':
      ensure => #{state},
    } ~>
    exec { 'service #{pkg} status':
      path      => $path,
      logoutput => true,
    }
  MANIFEST

  apply_manifest_on(agent, manifest) do
    if pkg == 'rabbitmq-server'
      if state == 'running'
        assert_match(/Status of node/m, stdout, "Could not start #{pkg}.")
      elsif
        assert_match(/unable to connect to node/m, stdout, "Could not stop #{pkg}.")
      end
    else
      if state == 'running'
        assert_match(/start/m, stdout, "Could not start #{pkg}.")
      elsif
        assert_match(/stop/m, stdout, "Could not stop #{pkg}.")
      end
    end
  end
end

begin
# in Precise these packages provide a mix of upstart with no linked init
# script (tty2), upstart linked to an init script (rsyslog), and no upstart
# script - only an init script (rabbitmq-server)
  %w(tty2 rsyslog rabbitmq-server).each do |pkg|

    on agent, puppet_resource("package #{pkg} ensure=present")

    # Cycle the services
    manage_service_for(pkg, "running", agent)
    manage_service_for(pkg, "stopped", agent)
    manage_service_for(pkg, "running", agent)
  end
end
