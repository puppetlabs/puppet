test_name "#11727: support stdin parsing in puppet parser validate"
confine :except, :platform => 'windows'

step "validate with a tty parses the default manifest"
on agents, puppet('parser', 'validate'), :pty => true do
  assert_match(/Validating the default manifest/, stdout,
               "no message about validating default manifest")
end

step "validate with redirection parses STDIN"
agents.each do |agent|
  pp = agent.tmpfile('11727.pp')
  create_remote_file agent, pp, 'notice("hello")'

  on agent, puppet('parser', 'validate', '<', pp) do
    assert_no_match(/Validating the default manifest/, stdout,
                    "there was message about validating default manifest despite redirect")
  end
end
