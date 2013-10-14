test_name 'puppet module changes (on a module with a removed file)'

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_removed_file')

on master, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")
on master, "rm -rf #{testdir}/nginx/README"

step 'Run module changes to check a module with a removed file'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [0] ) do

  assert_equal <<-STDERR, stderr
\e[1;31mWarning: 1 files modified\e[0m
  STDERR

  assert_equal <<-OUTPUT, stdout
README
  OUTPUT

end
