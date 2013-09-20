test_name "Should allow symlinks to directories as configuration directories"
confine :except, :platform => 'windows'

agents.each do |agent|
  step "Create the test confdir with a link to it"
  confdir = agent.tmpdir('puppet_conf-directory')
  conflink = agent.tmpfile('puppet_conf-symlink')

  on agent, "rm -rf #{conflink} #{confdir}"

  on agent, "mkdir #{confdir}"
  on agent, "ln -s #{confdir} #{conflink}"

  create_remote_file agent, "#{confdir}/puppet.conf", <<CONFFILE
[main]
certname = "awesome_certname"
CONFFILE

manifest = 'notify{"My certname is $clientcert": }'

  step "Run Puppet and ensure it used the conf file in the confdir"
  on agent, puppet_apply("--confdir #{conflink}"), :stdin => manifest do
    assert_match("My certname is awesome_certname", stdout)
  end

  step "Check that the symlink and confdir are unchanged"
  on agent, "[ -L #{conflink} ]"
  on agent, "[ -d #{confdir} ]"
  on agent, "[ $(readlink #{conflink}) = #{confdir} ]"
end
