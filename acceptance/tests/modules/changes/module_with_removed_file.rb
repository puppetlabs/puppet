test_name 'puppet module changes (on a module with a removed file)'

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_removed_file')

on master, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")
on master, "rm -rf #{testdir}/nginx/README"

step 'Run module changes to check a module with a removed file'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [0] ) do

  pattern = Regexp.new([
%Q{.*Warning: 1 files modified.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)

  assert_equal <<-OUTPUT, stdout
README
  OUTPUT

end
