test_name 'SysV on default Systemd Service Provider Validation' do

  confine :to, :platform => /el-|centos|fedora/ do |h|
    on h, 'which systemctl', :acceptable_exit_codes => [0, 1]
    stdout =~ /systemctl/
  end

  tag 'audit:medium',
      'audit:acceptance' # Could be done at the integration (or unit) layer though
                         # actual changing of resources could irreparably damage a
                         # host running this, or require special permissions.

  require 'puppet/acceptance/service_utils'
  extend Puppet::Acceptance::ServiceUtils

  svc = 'puppetize'
  initd_location = "/etc/init.d/#{svc}"
  pidfile = "/var/run/#{svc}.pid"

  # Some scripts don't have status command.
  def initd_file(svc, pidfile, initd_location, status)
    initd = <<INITD
#!/bin/bash
# #{svc} daemon
# chkconfig: 2345 20 80
# description: #{svc} daemon

DESC="#{svc} daemon"
PIDFILE=#{pidfile}
SCRIPTNAME=#{initd_location}

case "$1" in
start)
    PID=`/usr/bin/#{svc} 120 > /dev/null 2>&1 & echo $!`
    if [ -z $PID ]; then
        echo "Failed to start"
    else
        echo $PID > $PIDFILE
        echo "Started"
    fi
;;

#{if status then "status)" else "status-ignored)" end}
    if [ -f $PIDFILE ]; then
        PID=`cat $PIDFILE`
        if [ -z "`ps axf | grep ${PID} | grep -v grep `" ]; then
            printf "Process dead but pidfile exists"
            exit 2
        else
            echo "Running"
        fi
    else
        echo "Service not running"
        exit 3
    fi
;;

stop)
    PID=`cat $PIDFILE`
    if [ -f $PIDFILE ]; then
        kill -TERM $PID
        rm -f $PIDFILE
    else
        echo "pidfile not found"
    fi
;;

restart)
    $0 stop
    $0 start
;;

*)
    echo "Usage: $0 (start|stop|restart)"
    exit 1
esac

exit 0
INITD
  end

  def assert_service_status(agent, pidfile, expected_running)
    on agent, "ps -p `cat #{pidfile}`", :acceptable_exit_codes => (expected_running ? [0] : [1])
  end

  agents.each do |agent|
    on agent, 'which sleep'
    sleep_bin = stdout.chomp

    step "Create initd script with status command" do
      create_remote_file agent, initd_location, initd_file(svc, pidfile, initd_location, true)
      apply_manifest_on agent, <<MANIFEST
file {'/usr/bin/#{svc}': ensure => link, target => '#{sleep_bin}', }
file {'#{initd_location}': ensure => file, mode   => '0755', }
MANIFEST
      on agent, "chkconfig --add #{svc}"
      on agent, "chkconfig #{svc}", :acceptable_exit_codes => [0]
      on agent, "service #{svc} status", :acceptable_exit_codes => [3]
    end

    step "Verify the service exists on #{agent}" do
      assert_service_status_on_host(agent, svc, {:ensure => 'stopped', :enable => 'true'}) do
        assert_service_status(agent, pidfile, false)
      end
    end

    step "Start the service on #{agent}" do
      ensure_service_on_host(agent, svc, {:ensure => 'running'}) do
        assert_service_status(agent, pidfile, true)
      end
    end

    step "Disable the service on #{agent}" do
      ensure_service_on_host(agent, svc, {:enable => 'false'}) do
        assert_service_status(agent, pidfile, true)
      end
    end

    step "Stop the service on #{agent}" do
      ensure_service_on_host(agent, svc, {:ensure => 'stopped'}) do
        assert_service_status(agent, pidfile, false)
      end
    end

    step "Enable the service on #{agent}" do
      ensure_service_on_host(agent, svc, {:enable => 'true'}) do
        assert_service_status(agent, pidfile, false)
      end
    end

    step "Create initd script without status command" do
      create_remote_file agent, initd_location, initd_file(svc, pidfile, initd_location, false)
      apply_manifest_on agent, <<MANIFEST
file {'/usr/bin/#{svc}': ensure => link, target => '#{sleep_bin}', }
file {'#{initd_location}': ensure => file, mode   => '0755', }
MANIFEST
      on agent, "chkconfig --add #{svc}"
      on agent, "chkconfig #{svc}", :acceptable_exit_codes => [0]
      on agent, "service #{svc} status", :acceptable_exit_codes => [1]
    end

    step "Verify the service exists on #{agent}" do
      assert_service_status_on_host(agent, svc, {:ensure => 'stopped', :enable => 'true'}) do
        assert_service_status(agent, pidfile, false)
      end
    end

    # The following are implemented differently because currently the Redhat provider can't tell when
    # a service is running if it doesn't implement the status command. However it can still manage it.
    step "Start the service on #{agent}" do
      ensure_service_change_on_host(agent, svc, {:ensure => 'running'})
      assert_service_status(agent, pidfile, true)
      ensure_service_idempotent_on_host(agent, svc, {:ensure => 'running'})
      assert_service_status(agent, pidfile, true)
    end

    step "Disable the service on #{agent}" do
      ensure_service_change_on_host(agent, svc, {:enable => 'false'})
      assert_service_status(agent, pidfile, true)
      ensure_service_idempotent_on_host(agent, svc, {:enable => 'false'})
      assert_service_status(agent, pidfile, true)
    end

    step "Stop the service on #{agent}" do
      ensure_service_change_on_host(agent, svc, {:ensure => 'stopped'})
      assert_service_status(agent, pidfile, false)
      ensure_service_idempotent_on_host(agent, svc, {:ensure => 'stopped'})
      assert_service_status(agent, pidfile, false)
    end

    step "Enable the service on #{agent}" do
      ensure_service_change_on_host(agent, svc, {:enable => 'true'})
      assert_service_status(agent, pidfile, false)
      ensure_service_idempotent_on_host(agent, svc, {:enable => 'true'})
      assert_service_status(agent, pidfile, false)
    end

    teardown do
      on agent, "service #{svc} stop", :accept_any_exit_code => true
      on agent, "chkconfig --del #{svc}"
      on agent, "rm /usr/bin/#{svc} #{initd_location}"
    end
  end
end
