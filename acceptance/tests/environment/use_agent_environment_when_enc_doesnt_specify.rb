test_name "Agent should use agent environment if there is an enc that does not specify the environment"

testdir = master.tmpdir('use_agent_env')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['puppetbindir']}/ruby
puts <<YAML
parameters:
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

create_remote_file(master, "#{testdir}/different.pp", 'notify { "production environment": }')
create_remote_file(master, "#{testdir}/more_different.pp", 'notify { "more_different_string": }')

master_opts = {
  'main' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
    'manifest' => "#{testdir}/site.pp"
  },
  'production' => {
    'manifest' => "#{testdir}/different.pp"
  },
  'more_different' => {
    'manifest' => "#{testdir}/more_different.pp"
  }
}

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_puppet_running_on master, master_opts, testdir do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment more_different")
    assert_match(/more_different_string/, stdout, "Did not find more_different_string from \"more_different\" environment")
  end

end
