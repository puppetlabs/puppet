test_name "earlier modules take precendence over later modules in the modulepath"

step "Create some modules in the modulepath"
basedir = master.tmpdir("module_precedence")
module1libdir = "#{basedir}/1"
module2libdir = "#{basedir}/2"

apply_manifest_on(master, <<MANIFEST)
file { "#{basedir}":
  owner => #{master['group']},
  recurse => true,
  require => File[mod1, mod2]
}

Exec { path => "/bin:/usr/bin" }

exec { "mod1path": command => "mkdir -p #{module1libdir}/a/lib" }
exec { "mod2path": command => "mkdir -p #{module2libdir}/a/lib" }

file { "mod1":
  path => "#{module1libdir}/a/lib/foo.rb",
  content => "'from the first module'",
  owner => #{master['group']},
  require => Exec[mod1path]
}

file { "mod2":
  path => "#{module2libdir}/a/lib/foo.rb",
  content => "'from the second module'",
  owner => #{master['group']},
  require => Exec[mod2path]
}
MANIFEST

master_opts = {
  'master' => {
    'modulepath' => "#{module1libdir}:#{module2libdir}",
    'node_terminus' => 'plain',
  }
}

with_puppet_running_on master, master_opts, basedir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"))
    on agent, "cat #{agent['puppetvardir']}/lib/foo.rb" do
      assert_match(/from the first module/, stdout, "The synced plugin was not found or the wrong version was synced")
    end
  end
end
