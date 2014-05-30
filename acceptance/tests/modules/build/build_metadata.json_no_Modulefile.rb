test_name 'puppet module build - metadata.json with no Modulefile'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author       = 'pmtacceptance'
module_name         = 'nginx'
module_version      = '0.0.1'

teardown do
  apply_manifest_on(master, "file { '#{master['distmoduledir']}/#{module_name}': ensure => absent, force => true }")
end

step 'Setup - create metadata.json file' do
  apply_manifest_on(master, <<-PP
file {
  [
    '#{master['distmoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/metadata.json':
    content => '{
      "name": "#{module_author}-#{module_name}",
      "version": "#{module_version}",
      "author": "Puppet Labs",
      "summary": "#{module_name} Module",
      "license": "Apache 2.0",
      "source": "git://github.com/#{module_author}/#{module_author}-#{module_name}.git",
      "project_page": "http://github.com/#{module_author}/#{module_author}-#{module_name}",
      "issues_url": null
    }';
}
PP
  )
end

step 'Build module with metadata.json, but no Modulefile' do
  on(master, puppet("module build #{master['distmoduledir']}/#{module_name}"))
end

step 'Validate build files' do
  on(master, "[ -f #{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}/metadata.json ]")
  on(master, "[ -f #{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}.tar.gz ]")
end
