test_name "puppet module build - metadata.json and Modulefile"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

skip_test 'pending resolution of PE-4354'

module_author       = 'pmtacceptance'
module_name         = 'nginx'
module_version      = '0.0.1'

metadata_file = "#{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}/metadata.json"

teardown do
#  apply_manifest_on(master, "file { '#{master['distmoduledir']}/#{module_name}': ensure => absent, force => true }")
end

step 'Setup - apply metadata.json' do
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
      "project_page": "http://github.com/#{module_author}/#{module_author}-#{module_name}",
      "issues_url": null
    }';
}
PP
  )
end

step 'Setup - apply Modulefile' do
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
      project_page "http://github.com/#{module_author}/#{module_author}-ntp"
      dependency "#{module_author}/foobar", ">= 1.0.0"
';
}
PP
  )
end

step 'Build a module with metadata.json and Modulefile - verify error' do
  on(master, puppet("module build #{master['distmoduledir']}/#{module_name}")) do |res|
    pattern = Regexp.new("Warning: Modulefile is deprecated.")
    assert_match(pattern, res.stderr)
  end
end

step 'Verify module files and that Modulefile was not used to build metadata.json' do
  on(master, "[ -f #{master['distmoduledir']}/#{module_name}/pkg/#{module_author}-#{module_name}-#{module_version}.tar.gz ]")
  on(master, "[ -f #{metadata_file} ]")
  on(master, "cat #{metadata_file}") do |res|
    fail_test("Modulefile was used in module build") if res.stdout.include? 'foobar'
  end
end
