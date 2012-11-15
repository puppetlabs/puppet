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

with_master_running_on(master, "--dns_alt_names=\"puppet, $(facter hostname), $(facter fqdn)\" --rest_authconfig /tmp/auth.conf-7117 --verbose --autosign true") do
  agents.each do |agent|
    if agent['platform'].include?('windows')
      Log.warn("Pending: Window's doesn't support facter fqdn")
      next
    end

    # Run test on Agents
    step "Run agent to upload facts"
    on agent, puppet_agent("--test --server #{master}")
    fqdn = on(agent, facter("fqdn")).stdout

    step "Fetch agent facts from Puppet Master"
    on(agent, "curl -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/#{fqdn}") do
      assert_match(/--- !ruby\/object:Puppet::Node::Facts/, stdout, "Agent Facts not returned for #{agent}")
    end
  end
end
