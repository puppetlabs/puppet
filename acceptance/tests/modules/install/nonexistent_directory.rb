test_name "puppet module install (nonexistent directory)"

module_author = "pmtacceptance"
module_name   = "nginx"
module_dependencies  = []

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

apply_manifest_on master, <<-PP
  file { '/tmp/modules': ensure => absent, recurse => true, force => true }
PP

step "Try to install a module to a non-existent directory"
on master, puppet("module install #{module_author}-#{module_name} --target-dir /tmp/modules") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into /tmp/modules ...\e[0m
    \e[mNotice: Created target directory /tmp/modules\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    /tmp/modules
    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d /tmp/modules/#{module_name} ]"

# This test relies on destroying the default module directory...
#step "Try to install a module to a non-existent implicit directory"
#on master, puppet("module install #{module_author}-#{module_name}") do
#  assert_output <<-OUTPUT
#    \e[mNotice: Preparing to install into #{master['distmoduledir']} ...\e[0m
#    \e[mNotice: Created target directory #{master['distmoduledir']}\e[0m
#    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
#    \e[mNotice: Installing -- do not interrupt ...\e[0m
#    #{master['distmoduledir']}
#    └── #{module_author}-#{module_name} (\e[0;36mv0.0.1\e[0m)
#  OUTPUT
#end
#
#on master, '[ -d #{master['distmoduledir']}/#{module_name} ]'
