test_name "should create an email alias and update db"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) delete the aliases database
    on(agent, "rm /etc/aliases.db")

    #(teardown) restore the alias file
    on(agent, "mv /tmp/aliases /etc/aliases", :acceptable_exit_codes => [0,1])
    on(agent, "newaliases")
  end

  #------- SETUP -------#
  step "(setup) backup alias file"
  on(agent, "cp /etc/aliases /tmp/aliases", :acceptable_exit_codes => [0,1])

  #------- TESTS -------#
  step "create a mailalias with puppet"
  args = ['ensure=present',
          'recipient="foo,bar,baz"']
  on(agent, puppet_resource('mailalias', name, args))

  step "verify the alias exists"
  on(agent, "cat /etc/aliases")  do |res|
    assert_match(/#{name}:.*foo,bar,baz/, res.stdout, "mailalias not in aliases file")
  end

  step "verify name is in aliases.db"
  on(agent, "grep #{name} /etc/aliases.db", :acceptable_exit_codes => [0,1])  do |res|
    assert_match(/matches/, res.output, "mailalias not in aliases.db")
  end

end
