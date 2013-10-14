test_name "Agent should environment given by ENC"

testdir = master.tmpdir('use_enc_env')

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
    'external_nodes' => "#{testdir}/enc.rb",
    'manifest' => "#{testdir}/site.pp"
  },
  'special' => {
    'manifest' => "#{testdir}/different.pp"
  }
}

create_remote_file(master, "#{testdir}/different.pp", 'notify { "expected_string": }')

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_puppet_running_on master, master_opts, testdir do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose")
    assert_match(/expected_string/, stdout, "Did not find expected_string from \"special\" environment")
  end
end
