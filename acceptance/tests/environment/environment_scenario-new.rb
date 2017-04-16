test_name "Test a new environment, unknown to agent"
require 'pry'

step "setup environments"

testdir = create_tmpdir_for_user master, "confdir"
manifest = <<-MANIFEST
  File {
    ensure => directory,
    owner => #{master['user']},
    group => #{master['group']},
    mode => "0750",
  }

  file { "#{testdir}":;
    "#{testdir}/environments":;
    "#{testdir}/environments/production":;
    "#{testdir}/environments/production/manifests":;
    "#{testdir}/environments/production/modules":;
    "#{testdir}/environments/debug":;
    "#{testdir}/environments/debug/manifests":;
    "#{testdir}/environments/debug/modules":;
  }
  file { "#{testdir}/environments/production/manifests/site.pp":
    ensure  => file,
    content => 'node default{\nnotify{"fail!1!":}\n}'
  }
  file { "#{testdir}/environments/debug/manifests/site.pp":
    ensure  => file,
    content => 'node default{\nnotify{"you win":}\n}'
  }
MANIFEST

apply_manifest_on(master, manifest, :catch_failures => true)

step "run agents, ensure new environment used"

master_opts = {
  'main' => {
    'environmentpath' => "#{testdir}/environments",
  },
  'agent' => {
    'environment' => 'debug'
  }
}

with_puppet_running_on(master, master_opts, testdir) do
  agents.each do |agent|
    on(agent, puppet("agent", "--test"), :acceptable_exit_codes => (0..255) ) do
      assert_match(/you win/, stdout,
                   "agent did not pickup newly classified environment." )
    end
  end
end
