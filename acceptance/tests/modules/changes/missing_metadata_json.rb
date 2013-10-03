test_name 'puppet module changes (on a module which is missing metadata.json)'

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_on_invalid_metadata')

apply_manifest_on master, %Q{
  file { '#{testdir}/nginx': ensure => directory;
         '#{testdir}/nginx/Modulefile': ensure => present }
}

step 'Run module changes on a module witch is missing metadata.json'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [1] ) do

  assert_equal <<-STDERR, stderr
\e[1;31mError: No metadata.json found.\e[0m
\e[1;31mError: Try 'puppet help module changes' for usage\e[0m
  STDERR
end
