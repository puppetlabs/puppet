test_name 'puppet module build creates checksums.json'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = 'pmtacceptance'
module_name = 'nginx'
module_version = '0.0.1'

module_build_root = "#{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}"

teardown do
  apply_manifest_on(master, "file { '#{master['distmoduledir']}/#{module_name}': ensure => absent, force => true }")
end

step 'Setup - create metadata.json' do
  apply_manifest_on(master, <<-PP
file {
  [
    '#{master['distmoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}-#{module_name}",
      "version": "#{module_version}",
      "author": "#{module_author}",
      "summary": "#{module_name} Module",
      "license": "Apache 2.0",
      "source": "git://github.com/#{module_author}/#{module_author}-#{module_name}.git",
      "project_page": "http://github.com/#{module_author}/#{module_author}-ntp",
      "issues_url": null,
      "dependencies": [
        {
          "name": "#{module_author}-stdlub",
          "version_range": ">= 1.0.0"
        }
      ]
    }';
}
PP
  )
end

step "Build module" do
  on(master, puppet("module build #{master['distmoduledir']}/#{module_name}"))
end

step "Validate checksums.json for files in #{module_author}-#{module_name}" do
  verify_checksums_entries(master, module_build_root)
end

step "Add new file to module" do
  apply_manifest_on(master, <<-PP
file {
  [
    '#{master['distmoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/foo.txt':
    content => '{ foobar }';
}
PP
  )
end

step "Build module" do
  on(master, puppet("module build #{master['distmoduledir']}/#{module_name}"))
end

step "Validate checksums.json for files in #{module_author}-#{module_name}" do
  verify_checksums_entries(master, module_build_root)
end
