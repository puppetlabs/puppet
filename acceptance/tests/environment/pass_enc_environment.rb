test_name "ENC is passed environment from the agent"

testdir = master.tmpdir('pass_enc_env')

create_remote_file master, "#{testdir}/enc.rb", <<END
#!/usr/bin/env ruby

if ARGV[1] == 'special' then
  puts <<YAML
parameters:
  foobar: 'special-foobar'
YAML
else
  puts <<YAML
parameters:
  foobar: 'default-foobar'
YAML
end
END
on master, "chmod 755 #{testdir}/enc.rb"

create_remote_file master, "#{testdir}/puppet.conf", <<END
[main]
node_terminus = execenv
external_nodes = "#{testdir}/enc.rb"
manifest = "#{testdir}/site.pp"
END

create_remote_file(master, "#{testdir}/site.pp", 'notify { $::foobar: }')

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_master_running_on(master, "--config #{testdir}/puppet.conf --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment special")
    assert_match(/special-foobar/, stdout, "Did not find expected string special-foobar from \"special\" environment")
  end

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment default")
    assert_match(/default-foobar/, stdout, "Did not find expected string default-foobar from \"default\" environment")
  end
end

on master, "rm -rf #{testdir}"

