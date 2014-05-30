test_name 'puppet module build - malformed metadata.json'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

module_author       = 'pmtacceptance'
module_name         = 'nginx'
module_version      = '0.0.1'
module_dependencies = ['stdlub']


teardown do
  apply_manifest_on(master, "file { '#{master['distmoduledir']}/#{module_name}': ensure => absent, force => true }")
end

step 'Setup - apply malformed metadata.json' do
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
    }}}}}';
}
PP
  )
end

step 'Try to build a module with malformed metadata.json' do
  on(master, puppet("module build #{master['distmoduledir']}/nginx"), :acceptable_exit_codes => [1]) do |res|
    fail_test('Expected error not shown') unless res.stderr.include? 'Could not parse JSON'
  end
end
