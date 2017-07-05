test_name 'Upstart Testing'

# only run these on ubuntu vms
confine :to, :platform => 'ubuntu'
# vivid and above use systemd rather than upstart
confine :except, :platform => /ubuntu-1?[v-z|5-9]/

tag 'audit:low',
    'audit:delete',
    'audit:refactor',  # Use block style `test_run`
    'audit:acceptance' # Could be done at the integration (or unit) layer though
                       # actual changing of resources could irreparably damage a
                       # host running this, or require special permissions.

# pick any ubuntu agent
agent = agents.first
skip_test "No suitable hosts found" if agent.nil?

def manage_service_for(pkg, state, agent)

  return_code = 0

  if pkg == 'rabbitmq-server' && state == 'stopped'
    if agent['platform'].codename == 'lucid'
      return_code = 1
    else
      return_code = 3
    end
  end

  manifest = <<-MANIFEST
    service { '#{pkg}':
      ensure => #{state},
    } ~>
    exec { 'service #{pkg} status':
      path      => $path,
      logoutput => true,
      returns => #{return_code},
    }
  MANIFEST

  apply_manifest_on(agent, manifest, :catch_failures => true) do
    if pkg == 'rabbitmq-server'
      if state == 'running'
        assert_match(/Status of.*node/m, stdout, "Could not start #{pkg}.")
      else
        if agent['platform'].codename == 'lucid'
          assert_match(/no_nodes_running/, stdout, "Could not stop #{pkg}.")
        else
          assert_match(/unable to connect to node/, stdout, "Could not stop #{pkg}.")
        end
      end
    else
      if state == 'running'
        assert_match(/start/, stdout, "Could not start #{pkg}.")
      else
        assert_match(/stop/, stdout, "Could not stop #{pkg}.")
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
