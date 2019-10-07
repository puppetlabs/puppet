test_name 'puppet module changes (on a module which is missing metadata.json)'

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_on_invalid_metadata')

apply_manifest_on master, %Q{
  file { '#{testdir}/nginx': ensure => directory }
}

step 'Run module changes on a module which is missing metadata.json'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [1] ) do

  pattern = Regexp.new([
%Q{.*Error: Could not find a valid module at.*},
%Q{.*Error: Try 'puppet help module changes' for usage.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)
end
