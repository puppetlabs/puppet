test_name 'puppet module list (with environment)'
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tmpdir = master.tmpdir('module-list-with-environment')

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_directory_environments(tmpdir)

step 'List modules in a non default directory environment' do
  on master, puppet("module", "install",
                    "pmtacceptance-nginx",
                    "--config", puppet_conf,
                    "--environment=direnv")

  on master, puppet("module", "list",
                    "--config", puppet_conf,
                    "--environment=direnv") do

    assert_match(%r{#{tmpdir}/environments/direnv/modules}, stdout)
    assert_match(/pmtacceptance-nginx/, stdout)
  end
end
