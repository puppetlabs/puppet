test_name "(PUP-2455) Service provider should start Solaris init service in its own SMF contract"

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
      service { "vmware-tools":
      provider => "init",
      enable   => "true",
      ensure   => "running",
      status   => "/etc/init.d/vmware-tools status",
      }
    }
  ',
}
MANIFEST

  apply_manifest_on master, test_manifest

step "Start master"
  
  if master.is_pe?
    master['puppetservice'] = 'pe-puppetserver'
    agent_service           = 'pe-puppet'
  else
    master['puppetservice'] = 'puppetserver'
    agent_service           = 'puppet'
  end
 
  master_opts = {
    'main' => {
    'environmentpath' => "#{testdir}/environments",
    }
  }

  with_puppet_running_on master, master_opts, testdir do

    agents.each do |agent|

    fixture_process = 'vmtoolsd'
    fixture_resource = 'vmware-tools'
    fixture_service_stop = '/etc/init.d/vmware-tools stop'

      arch = on(agent, facter('architecture')).stdout.chomp
      plat = on(agent, facter('osfamily')).stdout.chomp

      skip_test unless arch == "i86pc" and plat == "Solaris" 

      step "Start the fixture service on #{agent} "
        on(agent, "puppet resource service #{fixture_resource} provider=init ensure=stopped")
        on(agent, "puppet resource service #{fixture_resource} provider=init ensure=running")

        assert_match(/ensure changed 'stopped' to 'running'/, stdout, "The fixture service #{fixture_process} is not in a testable state on #{agent}.")

      step "Verify whether the fixture process is alone in its SMF contract on #{agent}"
        service_ctid = on(agent, "sleep 20;ps -eo ctid,args | grep #{fixture_process} | grep -v grep | awk '{print $1}'").stdout.chomp.to_i
        number_in_contract = on(agent, "pgrep -c #{service_ctid} | wc -l").stdout.chomp.to_i

        assert(number_in_contract == 1, "The fixture process #{fixture_process} is not alone in its SMF contract on #{agent}.")

      if agent.is_pe? 

        step "Stop puppet on #{agent}"
          on(agent, "svcadm disable #{agent_service};sleep 70;svcadm disable #{agent_service}")

        step "Stop fixture service on #{agent}"
          on(agent, "#{fixture_service_stop}")

        step "Enable puppet service on #{agent}"
          on(agent, "svcadm enable #{agent_service};sleep 10") do
            puppet_ctid = on(agent, "svcs -Ho CTID #{agent_service} | awk '{print $1}'").stdout.chomp.to_i
            service_ctid = on(agent, "ps -eo ctid,args | grep #{fixture_process} | grep -v grep | awk '{print $1}'").stdout.chomp.to_i

          step "Compare SMF contract ids for puppet and #{fixture_process} on #{agent}"
            unless ( puppet_ctid != "0" and service_ctid != "0" ) then
              fail_test("SMF contract ids should not equal zero.")
            end

            assert(service_ctid != puppet_ctid, "Service is in the same SMF contract as puppet on #{agent}.")
         end 
       end
    end
  end
