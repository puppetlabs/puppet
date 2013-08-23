test_name "Agent should use environment given by ENC for fetching remote files"

testdir = master.tmpdir('respect_enc_test')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!#{master['puppetbindir']}/ruby
puts <<YAML
parameters:
environment: special
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

on master, "mkdir -p #{testdir}/modules"
# Create a plugin file on the master
on master, "mkdir -p #{testdir}/special/amod/files"
create_remote_file(master, "#{testdir}/special/amod/files/testy", "special_environment")

on master, "chown -R #{master['user']}:#{master['group']} #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

master_opts = {
  'master' => {
    'node_terminus' => 'exec',
    'external_nodes' => "#{testdir}/enc.rb",
    'filetimeout' => 1
  },
  'special' => {
    'modulepath' => "#{testdir}/special",
    'manifest' => "#{testdir}/different.pp"
  }
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|
    atmp = agent.tmpdir('respect_enc_test')
    logger.debug "agent: #{agent} \tagent.tmpdir => #{atmp}"

    create_remote_file master, "#{testdir}/different.pp", <<END
file { "#{atmp}/special_testy":
  source => "puppet:///modules/amod/testy",
}

notify { "mytemp is ${::mytemp}": }
END
    on master, "chmod 644 #{testdir}/different.pp"

    sleep 2 # Make sure the master has time to reload the file

    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --trace")

    on agent, "cat #{atmp}/special_testy" do |result|
      assert_match(/special_environment/,
                   result.stdout,
                   "The file from environment 'special' was not found")
    end

    on agent, "rm -rf #{atmp}"
  end
end
