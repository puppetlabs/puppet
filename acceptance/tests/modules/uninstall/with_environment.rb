test_name 'puppet module uninstall (with environment)'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

tmpdir = master.tmpdir('module-uninstall-with-environment')

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_directory_environments(tmpdir)

crakorn_metadata = <<-EOS
{
 "name": "jimmy/crakorn",
 "version": "0.4.0",
 "source": "",
 "author": "jimmy",
 "license": "MIT",
 "dependencies": []
}
EOS

# Configure a non-default environment
apply_manifest_on master, %Q{
  file {
    [
      '#{tmpdir}/environments/direnv/modules',
      '#{tmpdir}/environments/direnv/modules/crakorn',
    ]:
      ensure => directory,
  }
  file {
    '#{tmpdir}/environments/direnv/modules/crakorn/metadata.json':
      content => '#{crakorn_metadata}',
  }
}

step 'Uninstall a module from a non default directory environment' do
  environment_path = "#{tmpdir}/environments/direnv/modules"
  on(master, puppet("module uninstall jimmy-crakorn --config=#{puppet_conf} --environment=direnv")) do
    assert_equal <<-OUTPUT, stdout
\e[mNotice: Preparing to uninstall 'jimmy-crakorn' ...\e[0m
Removed 'jimmy-crakorn' (\e[0;36mv0.4.0\e[0m) from #{environment_path}
    OUTPUT
  end
  on master, "[ ! -d #{environment_path}/crackorn ]"
end
