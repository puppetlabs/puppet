test_name 'puppet module changes (on an invalid module install path)'

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not requiered for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_invalid_path')

step 'Run module changes on an invalid module install path'
on master, puppet("module changes #{testdir}/nginx"), :acceptable_exit_codes => [1] do
  pattern = Regexp.new([
%Q{.*Error: Could not find a valid module at "#{testdir}/nginx".*},
%Q{.*Error: Try 'puppet help module changes' for usage.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)
end
