test_name "puppet command with an unknown external command prints help"

tag 'audit:low',
    'audit:refactor', # Use block style `test_name`
    'audit:unit'      # basic command line handling

on(agents, puppet('unknown'), :acceptable_exit_codes => [1]) do
  assert_match(/See 'puppet help' for help on available puppet subcommands/, stdout)
end
