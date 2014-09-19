test_name 'puppet module list (with environment)'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tmpdir = master.tmpdir('environmentpath')

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_legacy_and_directory_environments(tmpdir)

install_test_module_in = lambda do |environment|
  on master, puppet("module", "install",
                    "pmtacceptance-nginx",
                    "--config", puppet_conf,
                    "--environment", environment)
end

check_module_list_in = lambda do |environment, environment_path|
  on master, puppet("module", "list",
                    "--config", puppet_conf,
                    "--environment", environment) do

    assert_match(/#{environment_path}/, stdout)
    assert_match(/pmtacceptance-nginx/, stdout)
  end
end

step 'List modules in a non default legacy environment' do
  install_test_module_in.call('legacyenv')
  check_module_list_in.call('legacyenv', "#{tmpdir}/legacyenv/modules")
end

step 'Enable directory environments' do
  on master, puppet("config", "set",
                    "environmentpath", "#{tmpdir}/environments",
                    "--section", "main",
                    "--config", puppet_conf)
end

step 'List modules in a non default directory environment' do
  install_test_module_in.call('direnv')
  check_module_list_in.call('direnv', "#{tmpdir}/environments/direnv/modules")
end
