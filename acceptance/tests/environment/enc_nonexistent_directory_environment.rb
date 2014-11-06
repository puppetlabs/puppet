test_name "Master should produce error if enc specifies a nonexistent environment"
testdir = create_tmpdir_for_user master, 'nonexistent_env'

apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner  => #{master.puppet['user']},
  group  => #{master.puppet['group']},
  mode   => '0770',
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

  "#{testdir}/enc.rb":
    ensure  => file,
    mode    => '0775',
    content => '#!#{master['puppetbindir']}/ruby
      puts "environment: doesnotexist"
    ';
}
MANIFEST

master_opts = {
  'main' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
    'environmentpath' => "#{testdir}/environments",
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    on(agent, puppet("agent -t --server #{master}"), :acceptable_exit_codes => [1]) do
      assert_match(/Could not find a directory environment named 'doesnotexist'/, stderr, "Errors when nonexistent environment is specified")
      assert_not_match(/In the production environment/, stdout, "Executed manifest from production environment")
    end
  end
end
