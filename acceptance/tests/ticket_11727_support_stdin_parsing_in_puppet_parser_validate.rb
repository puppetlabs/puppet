test_name "#11727: support stdin parsing in puppet parser validate"

pp = "/tmp/11727.pp"

step "validate with a tty parses the default manifest"
on agents, puppet(%w{parser validate}) do
  assert_match(/Validating the default manifest/, stdout,
               "no message about validating default manifest")
end

step "create the remote manifest file for redirection"
create_remote_file(agents, pp, 'notice("hello")')

step "validate with redirection parses STDIN"
on agents, puppet(%w{parser validate <}, pp) do
  assert_no_match(/Validating the default manifest/, stdout,
                  "there was message about validating default manifest despite redirect")
end
