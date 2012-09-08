test_name "Agent should use agent environment if there is no enc-specified environment"

testdir = master.tmpdir('use_agent_env')

create_remote_file master, "#{testdir}/puppet.conf", <<END
[main]
manifest = "#{testdir}/site.pp"

[production]
manifest = "#{testdir}/different.pp"

[more_different]
manifest = "#{testdir}/more_different.pp"
END

create_remote_file(master, "#{testdir}/different.pp", 'notify { "production environment": }')
create_remote_file(master, "#{testdir}/more_different.pp", 'notify { "more_different_string": }')

on master, "chown -R root:puppet #{testdir}"
on master, "chmod -R g+rwX #{testdir}"

with_master_running_on(master, "--config #{testdir}/puppet.conf --daemonize --dns_alt_names=\"puppet,$(facter hostname),$(facter fqdn)\" --autosign true") do

  agents.each do |agent|
    run_agent_on(agent, "--no-daemonize --onetime --server #{master} --verbose --environment more_different")
    assert_match(/more_different_string/, stdout, "Did not find more_different_string from \"more_different\" environment")
  end
end

on master, "rm -rf #{testdir}"
