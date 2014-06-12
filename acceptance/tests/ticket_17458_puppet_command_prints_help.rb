test_name "puppet command with an unknown external command prints help"

on(agents, puppet('unknown'), :acceptable_exit_codes => [1]) do
  assert_match(/See 'puppet help' for help on available puppet subcommands/, stdout)
end
