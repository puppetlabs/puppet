test_name "Agent should use the last server-specified environment if server is authoritative" do
  require 'puppet/acceptance/environment_utils'
  extend Puppet::Acceptance::EnvironmentUtils

  tag 'audit:high',
      'server'

  # Remove all traces of the last used environment
  teardown do
    agents.each do |agent|
      on(agent, puppet('config print lastrunfile')) do |command_result|
        agent.rm_rf(command_result.stdout)
      end
    end
  end

  testdir = create_tmpdir_for_user(master, 'use_enc_env')

  create_remote_file(master, "#{testdir}/enc.rb", <<END)
#!#{master['privatebindir'] || '/opt/puppetlabs/puppet/bin'}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
  on(master, "chmod 755 '#{testdir}/enc.rb'")

  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
  File {
    ensure => directory,
    mode => "0770",
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
  }
  file {
    '#{testdir}/environments':;
    '#{testdir}/environments/production':;
    '#{testdir}/environments/production/manifests':;
    '#{testdir}/environments/special/':;
    '#{testdir}/environments/special/manifests':;
  }
  file { '#{testdir}/environments/production/manifests/site.pp':
    ensure => file,
    mode => "0640",
    content => 'notify { "production environment": }',
  }
  file { '#{testdir}/environments/special/manifests/different.pp':
    ensure => file,
    mode => "0640",
    content => 'notify { "special environment": }',
  }
  MANIFEST

  master_opts = {
    'main' => {
      'environmentpath' => "#{testdir}/environments",
    },
  }
  master_opts['master'] = {
    'node_terminus'  => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
  } if !master.is_pe?

  with_puppet_running_on(master, master_opts, testdir) do
    agents.each do |agent|
      step 'ensure the lastrunfile is absent for the first run' do
        on(agent, puppet('config print lastrunfile')) do |command_result|
          agent.rm_rf(command_result.stdout)
        end
      end

      step 'first run: agent makes a node request to get the environment' do
        run_agent_on(agent, '--no-daemonize --onetime --debug') do |result|
          assert_match(/Local environment: 'production' doesn't match server specified node environment 'special', switching agent to 'special'/, result.stdout)
          assert_match(/Debug: HTTP GET .*\/puppet\/v3\/node/, result.stdout)
          assert_match(/Notice: special environment/, result.stdout)
        end
      end

      step 'second run: agent uses the environment from lastrunfile' do
        run_agent_on(agent, '--no-daemonize --onetime --debug') do |result|
          assert_match(/Debug: Successfully loaded last environment from the lastrunfile/, result.stdout)
          assert_match(/Notice: special environment/, result.stdout)
        end
      end
    end
  end
end
