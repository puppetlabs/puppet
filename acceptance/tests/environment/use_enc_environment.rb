test_name 'Agent should use environment given by ENC and only compile a catalog once' do
  require 'puppet/acceptance/classifier_utils.rb'
  extend Puppet::Acceptance::ClassifierUtils

  tag 'audit:medium',
      'audit:integration',
      'server'

  testdir = create_tmpdir_for_user(master, 'use_enc_env')

  if master.is_pe?
    group = {
        'name'               => 'Special Environment',
        'description'        => 'Classify our test agent nodes in the special environment.',
        'environment'        => 'special',
        'environment_trumps' => true,
    }
    create_group_for_nodes(agents, group)
  else

    create_remote_file(master, "#{testdir}/enc.rb", <<END)
#!#{master['privatebindir']}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
    on(master, "chmod 755 '#{testdir}/enc.rb'")

  end

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
    content => 'notify { "expected_string": }',
  }
  MANIFEST

  master_opts           = {
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
      run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose") do |result|
        assert_match(/expected_string/, result.stdout, "Did not find expected_string from \"special\" environment")
        caching_catalog_message_count = result.stdout.split(/Info: Caching catalog for/).length - 1
        assert_equal(caching_catalog_message_count, 1, 'Should only compile and cache the catalog once during the run')
      end
    end
  end
end