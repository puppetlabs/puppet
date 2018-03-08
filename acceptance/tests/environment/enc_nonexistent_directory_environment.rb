test_name "Master should produce error if enc specifies a nonexistent environment" do
  require 'puppet/acceptance/classifier_utils.rb'
  extend Puppet::Acceptance::ClassifierUtils

  tag 'audit:medium',
      'audit:unit',
      'server'

  testdir = create_tmpdir_for_user(master, 'nonexistent_env')

  apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner  => #{master.puppet['user']},
  group  => #{master.puppet['group']},
  mode   => '0755',
}

file {
  "#{testdir}":;
  "#{testdir}/environments":;
  "#{testdir}/environments/production":;
  "#{testdir}/environments/production/manifests":;
  "#{testdir}/environments/production/manifests/site.pp":
    ensure  => file,
    mode => '0644',
    content => 'notify { "In the production environment": }';
}
  MANIFEST

  if master.is_pe?
    group = {
        'name'               => 'Environment Does Not Exist',
        'description'        => 'Classify our test agent nodes in an environment that does not exist.',
        'environment'        => 'doesnotexist',
        'environment_trumps' => true,
    }
    create_group_for_nodes(agents, group)
  else
    apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
    file { "#{testdir}/enc.rb":
      ensure  => file,
      mode    => '0775',
      content => '#!#{master['privatebindir']}/ruby
        puts "environment: doesnotexist"
      ';
    }
    MANIFEST
  end

  master_opts           = {
      'main' => {
          'environmentpath' => "#{testdir}/environments",
      }
  }
  master_opts['master'] = {
      'node_terminus'  => 'exec',
      'external_nodes' => "#{testdir}/enc.rb",
  } if !master.is_pe?

  with_puppet_running_on(master, master_opts, testdir) do
    agents.each do |agent|
      on(agent, puppet("agent -t --server #{master} --verbose"), :acceptable_exit_codes => [1]) do |result|
        unless agent['locale'] == 'ja'
          assert_match(/Could not find a directory environment named 'doesnotexist'/, result.stderr, "Errors when nonexistent environment is specified")
        end
        assert_not_match(/In the production environment/, result.stdout, "Executed manifest from production environment")
      end
    end
  end
end
