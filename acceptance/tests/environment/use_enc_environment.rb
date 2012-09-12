test_name "Agent should environment given by ENC"

testdir = master.tmpdir('use_enc_env')

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
manifest = "#{testdir}/site.pp"

[special]
manifest = "#{testdir}/different.pp"
END

create_remote_file(master, "#{testdir}/different.pp", 'notify { "expected_string": }')

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_master_running_on(master, "--config #{testdir}/puppet.conf --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose")
    assert_match(/expected_string/, stdout, "Did not find expected_string from \"special\" environment")
  end
end

on master, "rm -rf #{testdir}"
