test_name "puppet command with an unknown external command prints help"

on agents, puppet('unknown') do
  assert_match(/See 'puppet help' for help on available puppet subcommands/, stdout)
end
