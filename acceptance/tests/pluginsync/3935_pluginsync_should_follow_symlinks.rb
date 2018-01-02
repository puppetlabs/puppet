test_name "pluginsync should not error when modulepath is a symlink and no modules have plugin directories"

tag 'audit:medium',
    'audit:integration',
    'server'

step "Create a modulepath directory which is a symlink and includes a module without facts.d or lib directories"
basedir = master.tmpdir("symlink_modulepath")

target           =  "#{basedir}/target_dir"
test_module_dir  =  "#{target}/module1"
link_dest        =  "#{basedir}/link_dest"
modulepath       =  "#{link_dest}"
modulepath << "#{master['sitemoduledir']}" if master.is_pe?

apply_manifest_on(master, <<MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  mode   => "0750",
  owner  => #{master.puppet['user']},
  group  => #{master.puppet['group']},
}

file {
  '#{basedir}':;
  '#{target}':;
  '#{test_module_dir}':;
}

file { '#{link_dest}':
  ensure => link,
  target => '#{target}',
}
MANIFEST

master_opts = {
  'main' => {
    'basemodulepath' => "#{modulepath}"
  }
}

with_puppet_running_on master, master_opts, basedir do
  agents.each do |agent|
    on(agent, puppet('agent', "-t --server #{master}"))
      assert_no_match(/Could not retrieve information from environment production source\(s\) puppet:\/\/\/pluginfacts/, stderr)
      assert_no_match(/Could not retrieve information from environment production source\(s\) puppet:\/\/\/plugins/, stderr)
  end
end
