test_name 'puppet module changes (on an invalid module install path)'

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_invalid_path')

step 'Run module changes on an invalid module install path'
on master, puppet("module changes #{testdir}/nginx"), :acceptable_exit_codes => [1] do
  assert_equal <<-STDERR, stderr
\e[1;31mError: Could not find a valid module at "#{testdir}/nginx"\e[0m
\e[1;31mError: Try 'puppet help module changes' for usage\e[0m
  STDERR
end
