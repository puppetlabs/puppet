test_name 'PUP-4413 3x forbidden environment names should be allowed in 4x'

tag 'audit:medium',
    'audit:unit',  # This should be covered at the unit layer.
    'audit:refactor',
    'audit:delete'


step 'setup environments'

testdir = create_tmpdir_for_user(master, 'forbidden_env')
manifest = <<-MANIFEST
  File {
    ensure => directory,
    owner => #{master.puppet['user']},
    group => #{master.puppet['group']},
    mode => "0750",
  }

  file { "#{testdir}":;
    "#{testdir}/environments":;
    "#{testdir}/environments/master":;
    "#{testdir}/environments/master/manifests":;
    "#{testdir}/environments/master/modules":;
    "#{testdir}/environments/main":;
    "#{testdir}/environments/main/manifests":;
    "#{testdir}/environments/main/modules":;
    "#{testdir}/environments/agent":;
    "#{testdir}/environments/agent/manifests":;
    "#{testdir}/environments/agent/modules":;
    "#{testdir}/environments/user":;
    "#{testdir}/environments/user/manifests":;
    "#{testdir}/environments/user/modules":;
  }
  file { "#{testdir}/environments/master/manifests/site.pp":
    ensure  => file,
    content => 'notify{"$::environment":}'
  }
  file { "#{testdir}/environments/main/manifests/site.pp":
    ensure  => file,
    content => 'notify{"$::environment":}'
  }
  file { "#{testdir}/environments/agent/manifests/site.pp":
    ensure  => file,
    content => 'notify{"$::environment":}'
  }
  file { "#{testdir}/environments/user/manifests/site.pp":
    ensure  => file,
    content => 'notify{"$::environment":}'
  }
MANIFEST

apply_manifest_on(master, manifest, :catch_failures => true)

step 'run agents, ensure no one complains about the environment'

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments"
  }
}

environments = ['master','main','agent','user']
with_puppet_running_on(master, master_opts, testdir) do
  agents.each do |agent|
    environments.each do |environment|
      on(agent, puppet('agent',
                       "--test --server #{master} --environment #{environment}"),
      :acceptable_exit_codes => 2)
    end
  end
end
