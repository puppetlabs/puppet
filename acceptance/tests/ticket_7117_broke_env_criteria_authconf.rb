test_name "#7117 Broke the environment criteria in auth.conf"

# add to auth.conf
add_2_authconf = %q{
path /
environment override
auth any
allow *
}

step "Create a temp auth.conf"
create_remote_file master, "/tmp/auth.conf-7117", add_2_authconf

on master, "chmod 644 /tmp/auth.conf-7117"

with_master_running_on(master, "--dns_alt_names=\"puppet, $(hostname -s), $(hostname -f)\" --rest_authconfig /tmp/auth.conf-7117 --verbose --autosign true") do
  # Run test on Agents
  step "Run agent to upload facts"
  on agents, puppet_agent("--test --server #{master}")

  step "Fetch agent facts from Puppet Master"
  agents.each do |host|
    on(host, "curl -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/\`hostname -f\`") do
      assert_match(/--- !ruby\/object:Puppet::Node::Facts/, stdout, "Agent Facts not returned for #{host}")
    end
  end
end
