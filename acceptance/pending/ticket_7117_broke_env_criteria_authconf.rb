test_name "#7117 Broke the environment criteria in auth.conf"

# curl -k -H "Accept: yaml" https://cent-55-64-1:8140/override/facts/cent-55-64-1.local

# add to auth.conf
add_2_authconf = %q{
path /
environment override
auth any
allow *
}

step "Save original auth.conf file and create a temp auth.conf"
on master, "cp #{config['puppetpath']}/auth.conf /tmp/auth.conf-7117; echo '#{add_2_authconf}' > #{config['puppetpath']}/auth.conf"

step "Fetch agent facts from Puppet Master"
on agents, "curl -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/cent-55-64-1.local"

step "Restore original auth.conf file"
on master, "cp -f /tmp/auth.conf-7117 #{config['puppetpath']}/auth.conf"
