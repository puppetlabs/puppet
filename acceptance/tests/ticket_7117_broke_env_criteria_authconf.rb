test_name "#7117 Broke the environment criteria in auth.conf"

# add to auth.conf
add_2_authconf = %q{
path /
environment override
auth any
allow *
}

step "Save original auth.conf file and create a temp auth.conf"
on master, "cp #{config['puppetpath']}/auth.conf /tmp/auth.conf-7117; echo '#{add_2_authconf}' > #{config['puppetpath']}/auth.conf"

# Kill running Puppet Master -- should not be running at this point
step "Master: kill running Puppet Master"
on master, "ps -U puppet | awk '/puppet/ { print \$1 }' | xargs kill || echo \"Puppet Master not running\""
step "Master: Start Puppet Master"
on master, puppet_master("--certdnsnames=\"puppet:$(hostname -s):$(hostname -f)\" --verbose --noop")
# allow Master to start and initialize environment
sleep 1



# Run test on Agents
step "Agent: agent --test"
on agents, puppet_agent("--test")

step "Fetch agent facts from Puppet Master"
agents.each do |host|
  on(host, "curl -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/\`hostname -f\`") do
    assert_match(/--- !ruby\/object:Puppet::Node::Facts/, stdout, "Agent Facts not returned for #{host}") 
  end
end

step "Restore original auth.conf file"
on master, "cp -f /tmp/auth.conf-7117 #{config['puppetpath']}/auth.conf"
