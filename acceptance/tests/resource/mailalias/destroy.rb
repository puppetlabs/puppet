test_name "should delete an email alias and update db"

name = "pl#{rand(999999).to_i}"

agents.each do |agent|
  teardown do
    #(teardown) restore the alias file
    on(agent, "mv /tmp/aliases /etc/aliases", :acceptable_exit_codes => [0,1])
    on(agent, "newaliases")
  end

  #------- SETUP -------#
  step "(setup) backup alias file"
  on(agent, "cp /etc/aliases /tmp/aliases", :acceptable_exit_codes => [0,1])

  step "(setup) create a mailalias"
  on(agent, "echo '#{name}: foo,bar,baz' >> /etc/aliases")
  on(agent, "newaliases")

  step "(setup) verify the alias exists"
  on(agent, "cat /etc/aliases")  do |res|
    assert_match(/#{name}:.*foo,bar,baz/, res.stdout, "mailalias not in aliases file")
  end

  step "(setup) verify name is in  aliases.db"
  on(agent, "grep #{name} /etc/aliases.db", :acceptable_exit_codes => [0,1])  do |res|
    assert_match(/matches/, res.output, "mailalias not in aliases.db")
  end

  #------- TESTS -------#
  step "delete the aliases database with puppet"
  args = ['ensure=absent',
          'recipient="foo,bar,baz"']
  on(agent, puppet_resource('mailalias', name, args))


  step "verify the alias is absent"
  on(agent, "cat /etc/aliases")  do |res|
    assert_no_match(/#{name}:.*foo,bar,baz/, res.stdout, "mailalias was not removed from aliases file")
  end

  step "verify name is not in aliases.db"
  on(agent, "grep #{name} /etc/aliases.db", :acceptable_exit_codes => [0,1])  do |res|
    assert_no_match(/matches/, res.output, "mailalias was not removed from aliases.db")
  end

end
