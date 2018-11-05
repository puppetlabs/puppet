test_name "SMF: basic tests" do
  confine :to, :platform => 'solaris'

  tag 'audit:medium',
      'audit:acceptance' # Could be done at the integration (or unit) layer though
                         # actual changing of resources could irreparably damage a
                         # host running this, or require special permissions.

  require 'puppet/acceptance/solaris_util'
  extend Puppet::Acceptance::SMFUtils

  require 'puppet/acceptance/service_utils'
  extend Puppet::Acceptance::ServiceUtils

  teardown do
    step "SMF: cleanup" do
      agents.each do |agent|
        clean agent, :service => 'tstapp'
      end
    end
  end

  agents.each do |agent|
    clean agent, :service => 'tstapp'

    run_nonexistent_service_tests('tstapp')

    manifest, _ = setup agent, :service => 'tstapp'

    step "SMF: ensure it is created with a manifest" do
      apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest) do
        assert_match( /ensure changed 'stopped'.* to 'running'/, result.stdout, "err: #{agent}")
      end
    end

    step "SMF: verify with svcs that the service is online" do
      on agent, "svcs -l application/tstapp" do
        assert_match( /state\s+online/, result.stdout, "err: #{agent}")
      end
    end

    step "SMF: ensure it is idempotent - ie not created again" do
      apply_manifest_on(agent, 'service {tstapp : ensure=>running, manifest=>"%s"}' % manifest, :catch_changes => true)
    end

    step "SMF: ensure you can query the service with the ral" do
      on(agent, puppet("resource service tstapp")) do
        assert_match( /ensure => 'running'/, result.stdout, "err: #{agent}")
      end
    end

    step "SMF: ensure you can stop the service" do
      apply_manifest_on(agent, 'service {tstapp : ensure=>stopped}') do
        assert_match( /changed 'running'.* to 'stopped'/, result.stdout, "err: #{agent}")
      end
    end

    step "SMF: verify with svcs that the service is not online" do
      on agent, "svcs -l application/tstapp", :acceptable_exit_codes => [0,1] do
        assert_no_match( /state\s+online/, result.stdout, "err: #{agent}")
      end
    end

    if agent['platform'] =~ /11/
      step "SMF: unset the general/complete property to mark the service as an incomplete service" do
        fmri = on(agent, "svcs -H -o fmri tstapp").stdout.chomp
        on(agent, "svccfg -s #{fmri} delprop general/complete") 
      end

      step "Verify that an incomplete service is considered stopped and disabled" do
        on(agent, puppet_resource('service', 'tstapp')) do |result|
          { enable: false, ensure: :stopped }.each do |property, value|
            assert_match(/#{property}.*#{value}.*$/, result.stdout, "Puppet does not report #{property}=#{value} for an incomplete service")
          end
        end
      end
      
      step "Verify that stopping and disabling an incomplete service is a no-op" do
        manifest =  service_manifest('tstapp', ensure: :stopped, enable: false)
        apply_manifest_on(agent, manifest, catch_changes: true)
      end
    end
  end
end
