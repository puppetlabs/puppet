test_name "puppet module install (force ignores dependencies)"

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

step "Try to install an unsatisfiable module"
on master, puppet("module install #{module_author}-#{module_name}"), :acceptable_exit_codes => [1] do
  assert_output <<-OUTPUT
    STDOUT> \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    STDOUT> \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    STDERR> \e[1;31mError: Could not install module '#{module_author}-#{module_name}' (latest: v0.0.2)
    STDERR>   No version of '#{module_author}-#{module_name}' will satisfy dependencies
    STDERR>     You specified '#{module_author}-#{module_name}' (latest: v0.0.2),
    STDERR>     which depends on '#{module_author}-apache' (v0.0.1),
    STDERR>     which depends on '#{module_author}-#{module_name}' (v0.0.1)
    STDERR>     Use `puppet module install --force` to install this module anyway\e[0m
  OUTPUT
end
on master, "[ ! -d #{master['distmoduledir']}/#{module_name} ]"
on master, "[ ! -d #{master['distmoduledir']}/apache ]"
module_dependencies.each do |dependency|
  on master, "[ ! -d #{master['distmoduledir']}/#{dependency} ]"
end

step "Install an unsatisfiable module with force"
on master, puppet("module install #{module_author}-#{module_name} --force") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['distmoduledir']}
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.2\e[0m)
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/#{module_name} ]"
module_dependencies.each do |dependency|
  on master, "[ ! -d #{master['distmoduledir']}/#{dependency} ]"
end
