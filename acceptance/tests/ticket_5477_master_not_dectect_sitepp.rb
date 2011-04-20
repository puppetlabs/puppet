# In 2.6, compile does not fail when site.pp does not exist.
#
# However, if a catalog is compiled when site.pp does not exist, 
# puppetmaster does not detect when site.pp is created. This requires a restart
# 
 
test_name "Ticket 5477, Puppet Master does not detect newly created site.pp file"

# Kill running Puppet Master
step "Master: kill running Puppet Master"
on master, "ps -U puppet | awk '/puppet/ { print \$1 }' | xargs kill"

# Run tests against Master first
step "Master: mv site.pp file to /tmp, if existing"
on master, "if [ -e  /etc/puppet/manifests/site.pp ] ; then mv /etc/puppet/manifests/site.pp /tmp/site.pp-5477 ; fi"

# Start Puppet Master
#step "Master: Run Puppet Master in verbose mode"
#on master, puppet_master("--verbose")
step "Master: Start Puppet Master"
on master, puppet_master("--certdnsnames=\"puppet:$(hostname -s):$(hostname -f)\" --verbose")

# Allow puppet server to start accepting conections
sleep 10

# Run test on Agents
step "Agent: agent --test"
agents.each { |agent|
    on agent, puppet_agent("--test")
}
 
# Create a new site.pp
step "Master: create basic site.pp file"
on master, "echo 'notify{ticket_5477_notify:}' > /etc/puppet/manifests/site.pp"

sleep 20

step "Agent: puppet agent --test"
agents.each { |agent|
  on agent, "puppet agent -t", :acceptable_exit_codes => [2]
  fail_test "Site.pp not detect at Master?" unless
    stdout.include? 'ticket_5477_notify'
}
