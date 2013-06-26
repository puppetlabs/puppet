test_name "puppet module list (with no installed modules)"


step "List the installed modules"
on master, puppet("module list") do
  assert_equal '', stderr
  assert_match /no modules installed/, stdout,
        "Declaration of 'no modules installed' not found"
end
