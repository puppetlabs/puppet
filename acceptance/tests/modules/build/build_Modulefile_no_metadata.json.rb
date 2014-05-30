test_name 'puppet module build - Modulefile with no metadata.json'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author = 'pmtacceptance'
module_name = 'ng1nx'
module_version = '0.0.1'

teardown do
  apply_manifest_on(master, "file { '#{master['distmoduledir']}/#{module_name}': ensure => absent, force => true }")
end

step 'Setup - create Modulefile' do
  apply_manifest_on(master, <<-PP
file {
  [
    '#{master['distmoduledir']}/#{module_name}',
  ]: ensure => directory;
  '#{master['distmoduledir']}/#{module_name}/Modulefile':
    content => 'name "#{module_author}-#{module_name}"
    version "#{module_version}"
    source "git://github.com/#{module_author}/#{module_author}-#{module_name}.git"
    author "#{module_author}"
    license "Apache Version 2.0"
    summary "#{module_name} Module"
    description "#{module_name}"
    project_page "http://github.com/#{module_author}/#{module_author}-#{module_name}"
    ';
}
PP
  )
end

step 'Try to build a module - validate error' do
  on(master, puppet("module build #{master['distmoduledir']}/#{module_name}")) do |res|
    pattern = Regexp.new("Warning: Modulefile is deprecated. Building metadata.json from Modulefile.")
    assert_match(pattern, res.stderr)
  end
end

step 'Validate module files' do
  on(master, "[ -f #{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}/metadata.json ]")
  on(master, "[ -f #{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}.tar.gz ]")
end
