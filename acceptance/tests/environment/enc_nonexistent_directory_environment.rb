test_name "Master should produce error if enc specifies a nonexistent environment"
testdir = create_tmpdir_for_user master, 'nonexistent_env'

apply_manifest_on master, <<-MANIFEST
file {
  [  "#{testdir}/environments", "#{testdir}/environments/production" ]:
  ensure => directory,
}

file { "#{testdir}/environments/production/environment.conf":
    ensure  => file,
    content => '
      manifest=./production.pp
    ',
}

file { "#{testdir}/environments/production/production.pp":
  ensure  => file,
  content => 'notify { "In the production environment": }',
}

file { "#{testdir}/enc.rb":
  ensure  => file,
  mode    => '0775',
  content => 'echo "environment: doesnotexist"',
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
    on agent, "puppet agent --no-daemonize --onetime --server #{master} --verbose", :acceptable_exit_codes => [0] do
      assert_match(/Could not find a directory environment named 'doesnotexist'/, stderr, "Errors when nonexistant environment is specified")
    end
  end
end
