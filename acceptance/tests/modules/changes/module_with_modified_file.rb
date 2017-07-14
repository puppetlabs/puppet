test_name 'puppet module changes (on a module with a modified file)'

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_modified_file')

on master, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")
on master, "echo >> #{testdir}/nginx/README"

step 'Run module changes to check a module with a modified file'
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
