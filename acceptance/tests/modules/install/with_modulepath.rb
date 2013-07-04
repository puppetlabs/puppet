# encoding: UTF-8

test_name "puppet module install (with modulepath)"

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies   = []

expected_output = <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['puppetpath']}/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['puppetpath']}/modules2
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
OUTPUT

teardown do
  on master, "rm -rf #{master['distmoduledir']}/*"
  agents.each do |agent|
    on agent, "rm -rf #{agent['distmoduledir']}/*"
  end
  on master, "rm -rf #{master['sitemoduledir']}/#{module_name}"
  module_dependencies.each do |dependency|
    on master, "rm -rf #{master['sitemoduledir']}/#{dependency}"
  end
  # TODO: Refactor
  on master, "rm -rf #{master['puppetpath']}/modules2"
end

step 'Setup'

stub_forge_on(master)

on master, "mkdir -p #{master['puppetpath']}/modules2"

step "Install a module with relative modulepath"
on master, "cd #{master['puppetpath']}/modules2 && puppet module install #{module_author}-#{module_name} --modulepath=." do
  assert_output expected_output
end
on master, "[ -d #{master['puppetpath']}/modules2/#{module_name} ]"

step "Install a module with absolute modulepath"
on master, "test -d #{master['puppetpath']}/modules2/#{module_name} && rm -rf #{master['puppetpath']}/modules2/#{module_name}"
on master, puppet("module install #{module_author}-#{module_name} --modulepath=#{master['puppetpath']}/modules2") do
  assert_output expected_output
end
on master, "[ -d #{master['puppetpath']}/modules2/#{module_name} ]"
