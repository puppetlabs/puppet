require 'puppet/acceptance/config_utils'
extend Puppet::Acceptance::ConfigUtils

# Windows doesn't suppoert Facter fqdn properly
confine :except, :platform => 'windows'

test_name "#7117 Broke the environment criteria in auth.conf"
testdir = master.tmpdir('env_in_auth_conf')

# add to auth.conf
add_2_authconf = %q{
path /
environment override
auth any
allow *
}

step "Create a temp auth.conf"
create_remote_file master, "#{testdir}/auth.conf", add_2_authconf

on master, "chmod 644 #{testdir}/auth.conf"
on master, "chmod 777 #{testdir}"

with_puppet_running_on master, {'master' => {'rest_authconfig' => "#{testdir}/auth.conf"}}, testdir do
  agents.each do |agent|

    # Run test on Agents
    step "Run agent to upload facts"
    on agent, puppet_agent("--test --server #{master}")
    # this is used in place of agent below, the issue is that PE forces certnames to be the short name
    # while foss by default uses fqdn... this needs to be reconsiliated before this test will be portable
    # fqdn = on(agent, facter('fqdn')).stdout.chomp

    step "Fetch agent facts from Puppet Master"
    on(agent, "curl -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/#{agent}") do
      assert_match(/--- !ruby\/object:Puppet::Node::Facts/, stdout, "Agent Facts not returned for #{agent}")
    end
  end
end
