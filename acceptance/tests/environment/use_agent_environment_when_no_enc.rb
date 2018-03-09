test_name "Agent should use agent environment if there is no enc-specified environment" do

  tag 'audit:medium',
      'audit:integration',
      'audit:refactor', # This can be combined with use_agent_environment_when_enc_doesnt_specify test
      'server'

  testdir = create_tmpdir_for_user(master, 'use_agent_env')

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
    '#{testdir}/environments/more_different/':;
    '#{testdir}/environments/more_different/manifests':;
  }
  file { '#{testdir}/environments/production/manifests/site.pp':
    ensure => file,
    mode => "0640",
    content => 'notify { "production environment": }',
  }
  file { '#{testdir}/environments/more_different/manifests/more_different.pp':
    ensure => file,
    mode => "0640",
    content => 'notify { "more_different_string": }',
  }
  MANIFEST

  master_opts = {
      'main'   => {
          'environmentpath' => "#{testdir}/environments",
      },
      'master' => {
          'node_terminus' => 'plain'
      },
  }

  with_puppet_running_on(master, master_opts, testdir) do

    agents.each do |agent|
      run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment more_different") do |result|
        assert_match(/more_different_string/, result.stdout, "Did not find more_different_string from \"more_different\" environment")
      end
    end
  end
end
