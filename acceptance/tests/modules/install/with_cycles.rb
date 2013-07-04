test_name "puppet module install (with cycles)"

module_author = "pmtacceptance"
module_name   = "php"
module_dependencies   = ["apache"]

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

step "Install a module with cycles"
on master, puppet("module install #{module_author}-#{module_name} --version 0.0.1") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └─┬ #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
      └── #{module_author}-apache (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end

# This isn't going to work
on master, puppet("module list --modulepath #{master['distmoduledir']}") do |res|
  assert_output <<-OUTPUT
    #{master['distmoduledir']}
    ├── #{module_author}-apache (\e[0;36mv0.0.1\e[0m)
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
