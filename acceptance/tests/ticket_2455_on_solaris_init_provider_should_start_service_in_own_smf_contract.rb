test_name "(PUP-2455) Service provider should start Solaris init service in its own SMF contract"

tag 'audit:medium',
    'audit:refactor',  # Use block style `test_name`
                       # Use mk_temp_environment_with_teardown
                       # Combine with Service resource tests
    'audit:acceptance' # Service provider functionality

skip_test unless agents.any? {|agent| agent['platform'] =~ /solaris/ }

sleepy_daemon_initscript = <<INITSCRIPT
#!/usr/bin/bash
FIXTURESERVICE="/tmp/sleepy_daemon"
start(){
    $FIXTURESERVICE &
}

stop(){
    FIXTUREPID=`ps -ef | grep "$FIXTURESERVICE" | grep -v grep | awk '{print $2}'`
    if [ "x$FIXTUREPID" != "x" ]; then
      kill -9 ${FIXTUREPID}
    fi
}

status(){
    FIXTUREPID=`ps -ef | grep "$FIXTURESERVICE" | grep -v grep | awk '{print $2}'`
    if [ "x$FIXTUREPID" = "x" ]; then
      exit 1
    else
      exit 0
    fi
}
case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    status)
        status
        ;;
esac
INITSCRIPT

step "Setup fixture service manifest on master"

  testdir = master.tmpdir('solaris_services_in_own_smf_contract')

  test_manifest = <<MANIFEST
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}
file { '#{testdir}': }
file { '#{testdir}/environments': }
file { '#{testdir}/environments/production': }
file { '#{testdir}/environments/production/manifests': }
file { '#{testdir}/environments/production/manifests/site.pp':
  ensure  => file,
  content => '
    node default {
      service { "sleepy_daemon":
      provider => "init",
      enable   => "true",
      ensure   => "running",
      status   => "/etc/init.d/sleepy_daemon status",
      }
    }
  ',
}
MANIFEST

  apply_manifest_on master, test_manifest

step "Start master"

  master_opts = {
    'main' => {
    'environmentpath' => "#{testdir}/environments",
    }
  }

  with_puppet_running_on master, master_opts, testdir do

    agents.each do |agent|

    fixture_service = 'sleepy_daemon'
    fixture_service_stop = '/etc/init.d/sleepy_daemon stop'

      next unless agent['platform'] =~ /solaris/

      step "Setup fixture service on #{agent}"
        sleepy_daemon_script = <<SCRIPT
#!#{agent['privatebindir']}/ruby
while true
  sleep (2)
end
SCRIPT
        sleepy_daemon_path = "/tmp/sleepy_daemon"
        sleepy_daemon_initscript_path = "/etc/init.d/sleepy_daemon"
        create_remote_file(agent, sleepy_daemon_path, sleepy_daemon_script)
        create_remote_file(agent, sleepy_daemon_initscript_path, sleepy_daemon_initscript)
        on(agent, "chmod +x #{sleepy_daemon_path} #{sleepy_daemon_initscript_path}")

      step "Start the fixture service on #{agent} "
        on(agent, puppet("resource service #{fixture_service} provider=init ensure=stopped"))
        on(agent, puppet("resource service #{fixture_service} provider=init ensure=running"))

        assert_match(/ensure changed 'stopped' to 'running'/, stdout, "The fixture service #{fixture_service} is not in a testable state on #{agent}.")

      step "Verify whether the fixture process is alone in its SMF contract on #{agent}"
        service_ctid = on(agent, "sleep 10;ps -eo ctid,args | grep #{fixture_service} | grep -v grep | awk '{print $1}'").stdout.chomp.to_i
        number_in_contract = on(agent, "pgrep -c #{service_ctid} | wc -l").stdout.chomp.to_i
        assert(number_in_contract == 1, "The fixture process #{fixture_service} is not alone in its SMF contract on #{agent}.")

      if agent.is_pe?

        step "Stop puppet on #{agent}"
          on(agent, "svcadm disable pe-puppet;sleep 70;svcadm disable pe-puppet")

        step "Stop fixture service on #{agent}"
          on(agent, "#{fixture_service_stop}")

        step "Enable puppet service on #{agent}"
          on(agent, "svcadm enable pe-puppet;sleep 10") do
            puppet_ctid = on(agent, "svcs -Ho CTID pe-puppet | awk '{print $1}'").stdout.chomp.to_i
            service_ctid = on(agent, "ps -eo ctid,args | grep #{fixture_service} | grep -v grep | awk '{print $1}'").stdout.chomp.to_i

          step "Compare SMF contract ids for puppet and #{fixture_service} on #{agent}"
            unless ( puppet_ctid != "0" and service_ctid != "0" ) then
              fail_test("SMF contract ids should not equal zero.")
            end

            assert(service_ctid != puppet_ctid, "Service is in the same SMF contract as puppet on #{agent}.")
         end
       end
    end
  end
