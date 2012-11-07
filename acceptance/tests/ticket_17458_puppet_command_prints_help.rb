test_name "puppet command alone prints help"

on agents, puppet('unknown') do
  assert_match(/See 'puppet help' for help on available puppet subcommands/, stdout)
end
