test_name "puppet module upgrade (with environment)"
require 'puppet/acceptance/module_utils'
extend Puppet::Acceptance::ModuleUtils

tag 'audit:low',       # Module management via pmt is not the primary support workflow
    'audit:acceptance',
    'audit:refactor'   # Master is not required for this test. Replace with agents.each
                       # Wrap steps in blocks in accordance with Beaker style guide

tmpdir = master.tmpdir('module-upgrade-withenv')

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies = ["stdlub"]

step 'Setup'

stub_forge_on(master)

puppet_conf = generate_base_directory_environments(tmpdir)

step "Upgrade a module that has a more recent version published in a directory environment" do
  on master, puppet("module install #{module_author}-#{module_name} --config=#{puppet_conf} --version 1.6.0 --environment=direnv") do
    assert_module_installed_ui(stdout, module_author, module_name)
  end

  environment_path = "#{tmpdir}/environments/direnv/modules"
  on master, puppet("module upgrade #{module_author}-#{module_name} --config=#{puppet_conf} --environment=direnv") do
    assert_module_installed_ui(stdout, module_author, module_name)
    on master, "[ -f #{environment_path}/#{module_name}/Modulefile ]"
    on master, "grep 1.7.1 #{environment_path}/#{module_name}/Modulefile"
  end
end
