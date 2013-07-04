test_name "puppet module install (ignoring dependencies)"

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
    on master, "rm -fr #{master['sitemoduledir']}/#{dependency}"
  end
end

step 'Setup'
stub_forge_on(master)

step "Install a module, but ignore dependencies"
on master, puppet("module install #{module_author}-#{module_name} --ignore-dependencies") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv1.7.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
module_dependencies.each do |dependency|
  on master, "[ ! -d #{master['distmoduledir']}/#{dependency} ]"
end
