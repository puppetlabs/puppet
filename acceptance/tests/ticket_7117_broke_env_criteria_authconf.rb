# Windows doesn't suppoert Facter fqdn properly
confine :except, :platform => 'windows'

test_name "#7117 Broke the environment criteria in auth.conf"

testdir = create_tmpdir_for_user master, 'env_in_auth_conf'


apply_manifest_on(master, <<-MANIFEST, :catch_failures => true)
File {
  ensure => directory,
  owner => #{master.puppet['user']},
  group => #{master.puppet['group']},
  mode => "0770",
}

file {
  "#{testdir}":;
  "#{testdir}/environments":;
  "#{testdir}/environments/override":;
  "#{testdir}/auth.conf":
    ensure => file,
    content => "
path /
environment override
auth any
allow *
",
    mode => "0640",
}
MANIFEST

master_opts = {
  'main' => { 'environmentpath' => "#{testdir}/environments" },
  'master' => { 'rest_authconfig' => "#{testdir}/auth.conf" },
}

with_puppet_running_on master, master_opts, testdir do
  agents.each do |agent|

    # Run test on Agents
    step "Run agent to upload facts"
    on agent, puppet_agent("--test --server #{master}")

    certname = master.is_pe? ?
       agent.to_s :
       on(agent, facter('fqdn')).stdout.chomp

    step "Fetch agent facts from Puppet Master"
    on(agent, "curl --tlsv1 -k -H \"Accept: yaml\" https://#{master}:8140/override/facts/#{certname}") do
      assert_match(/--- !ruby\/object:Puppet::Node::Facts/, stdout, "Agent Facts not returned for #{agent}")
    end
  end
end
