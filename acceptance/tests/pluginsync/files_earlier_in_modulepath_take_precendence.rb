test_name "earlier modules take precendence over later modules in the modulepath"

tag 'audit:medium',
    'audit:integration',
    'server'

step "Create some modules in the modulepath"
basedir = master.tmpdir("module_precedence")

module_dir1 = "#{basedir}/environments/production/modules1"
module_dir2 = "#{basedir}/modules2"
modulepath = "#{module_dir1}:#{module_dir2}"
modulepath << ":#{master['sitemoduledir']}" if master.is_pe?

apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  mode => "0750",
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
}

file {
  '#{basedir}':;
  '#{module_dir2}':;
  '#{module_dir2}/a':;
  '#{module_dir2}/a/lib':;
  '#{basedir}/environments':;
  '#{basedir}/environments/production':;
  '#{module_dir1}':;
  '#{module_dir1}/a':;
  '#{module_dir1}/a/lib':;
}

file { '#{basedir}/environments/production/environment.conf':
  ensure => file,
  content => "modulepath='#{modulepath}'",
  mode => "0640",
}

file { "mod1":
  ensure => file,
  path => "#{module_dir1}/a/lib/foo.rb",
  content => "'from the first module'",
  mode => "0640",
}

file { "mod2":
  ensure => file,
  path => "#{module_dir2}/a/lib/foo.rb",
  content => "'from the second module'",
  mode => "0640",
}
MANIFEST

master_opts = {
  'main' => {
    'environmentpath' => "#{basedir}/environments",
  }
}

with_puppet_running_on master, master_opts, basedir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"))
    on agent, "cat \"#{agent.puppet['vardir']}/lib/foo.rb\"" do
      assert_match(/from the first module/, stdout, "The synced plugin was not found or the wrong version was synced")
    end
  end
end
