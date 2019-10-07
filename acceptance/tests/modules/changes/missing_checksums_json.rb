test_name 'puppet module changes (on a module which is missing checksums.json)'

tag 'audit:medium',
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

step 'Setup'

stub_forge_on(master)
testdir = master.tmpdir('module_changes_on_invalid_checksums')

apply_manifest_on master, %Q{
  file { '#{testdir}/nginx': ensure => directory;
         '#{testdir}/nginx/metadata.json': ensure => present,
           content => '
{
  "name": "puppetlabs-nginx",
  "version": "0.0.1",
  "author": "Puppet Labs",
  "summary": "Nginx Module",
  "license": "Apache Version 2.0",
  "source": "git://github.com/puppetlabs/puppetlabs-nginx.git",
  "project_page": "https://github.com/puppetlabs/puppetlabs-nginx",
  "issues_url": "https://github.com/puppetlabs/puppetlabs-nginx",
  "dependencies": [
    {"name":"puppetlabs-stdlub","version_requirement":">= 1.0.0"}
  ]
}'
  }
}

step 'Run module changes on a module which is missing checksums.json'
on( master, puppet("module changes #{testdir}/nginx"),
    :acceptable_exit_codes => [1] ) do

  pattern = Regexp.new([
%Q{.*Error: No file containing checksums found.*},
%Q{.*Error: Try 'puppet help module changes' for usage.*},
  ].join("\n"), Regexp::MULTILINE)
  assert_match(pattern, result.stderr)
end
