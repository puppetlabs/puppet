test_name "puppet module install (with unnecessary dependency upgrade)"

module_author = "pmtacceptance"
module_name   = "java"
module_dependencies   = ["stdlib"]

teardown do
  on master, "rm -rf #{master['distmoduledir']}/*"
  agents.each do |agent|
    on agent, "rm -rf #{agent['distmoduledir']}/*"
  end
  on master, "rm -rf #{master['sitemoduledir']}/#{module_name}"
  module_dependencies.each do |dependency|
    on master, "rm -rf #{master['sitemoduledir']}/#{dependency}"
  end
end
step 'Setup'

stub_forge_on(master)

step "Install an older module version"
on master, puppet("module install #{module_author}-#{module_name} --version 1.7.0") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ #{module_author}-#{module_name} (\e[0;36mv1.7.0\e[0m)
      └── #{module_author}-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end

on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── #{module_author}-#{module_name} (\e[0;36mv1.7.0\e[0m)
    └── #{module_author}-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end


step "Install a module that depends on a dependency that could be upgraded, but already satisfies constraints"
module_name   = "apollo"
on master, puppet("module install #{module_author}-#{module_name}") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

on master, puppet("module list --modulepath #{master['distmoduledir']}") do
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
    ├── #{module_author}-java (\e[0;36mv1.7.0\e[0m)
    └── #{module_author}-stdlib (\e[0;36mv1.0.0\e[0m)
  OUTPUT
end
