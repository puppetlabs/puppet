test_name "Agent should use environment given by ENC for pluginsync"

testdir = master.tmpdir('respect_enc_test')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['puppetbindir']}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

master_opts = {
  'master' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb"
  },
  'special' => {
    'modulepath' => "#{testdir}/special"
  }
}

on master, "mkdir -p #{testdir}/modules"
# Create a plugin file on the master
on master, "mkdir -p #{testdir}/special/amod/lib/puppet"
create_remote_file(master, "#{testdir}/special/amod/lib/puppet/foo.rb", "#special_version")

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_puppet_running_on master, master_opts, testdir do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master}")
    on agent, "cat #{agent['puppetvardir']}/lib/puppet/foo.rb"
    assert_match(/#special_version/, stdout, "The plugin from environment 'special' was not synced")
    on agent, "rm -rf #{agent['puppetvardir']}/lib"
  end
end
