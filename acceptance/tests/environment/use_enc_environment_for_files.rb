test_name "Agent should use environment given by ENC for fetching remote files"

testdir = master.tmpdir('respect_enc_test')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!/usr/bin/env ruby
puts <<YAML
parameters:
environment: special
YAML
END
on master, "chmod 755 #{testdir}/enc.rb"

create_remote_file master, "#{testdir}/puppet.conf", <<END
[main]
node_terminus = exec
external_nodes = "#{testdir}/enc.rb"

[special]
modulepath = "#{testdir}/special"
manifest = "#{testdir}/different.pp"
END

on master, "mkdir -p #{testdir}/modules"
# Create a plugin file on the master
on master, "mkdir -p #{testdir}/special/amod/files"
create_remote_file(master, "#{testdir}/special/amod/files/testy", "special_environment")

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

agents.each do |agent|
  with_master_running_on(master, "--config #{testdir}/puppet.conf --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do
    atmp = agent.tmpdir('respect_enc_test')
    puts "agent: #{agent} \tagent.tmpdir => #{atmp}"
    create_remote_file master, "#{testdir}/different.pp", <<END
file { "#{atmp}/special_testy":
  source => "puppet:///modules/amod/testy",
}

notify { "mytemp is ${::mytemp}": }
END
    on master, "chmod 644 #{testdir}/different.pp"

    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --trace")
    on agent, "cat #{atmp}/special_testy"
    assert_match(/special_environment/, stdout, "The file from environment 'special' was not found")
    on agent, "rm -rf #{atmp}"
  end
end

on master, "rm -rf #{testdir}"
