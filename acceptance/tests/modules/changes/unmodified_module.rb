test_name 'puppet module changes (on an unmodified module)'

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_with_unmodified')

on master, puppet("module install pmtacceptance-nginx --modulepath #{testdir}")

step 'Run module changes to check an unmodified module'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [0] ) do

  assert_match /No modified files/, stdout
end
