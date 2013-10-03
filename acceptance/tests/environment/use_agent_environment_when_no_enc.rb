test_name "Agent should use agent environment if there is no enc-specified environment"

testdir = master.tmpdir('use_agent_env')

create_remote_file(master, "#{testdir}/different.pp", 'notify { "production environment": }')
create_remote_file(master, "#{testdir}/more_different.pp", 'notify { "more_different_string": }')

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

master_opts = {
  'main' => {
    'manifest' => "#{testdir}/site.pp"
  },
  'production' => {
    'manifest' => "#{testdir}/different.pp"
  },
  'more_different' => {
    'manifest' => "#{testdir}/more_different.pp"
  }
}

with_puppet_running_on master, master_opts, testdir do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment more_different")
    assert_match(/more_different_string/, stdout, "Did not find more_different_string from \"more_different\" environment")
  end
end
