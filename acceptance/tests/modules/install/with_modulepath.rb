# encoding: UTF-8

test_name "puppet module install (with modulepath)"

step 'Setup'

stub_forge_on(master)

on master, "mkdir -p #{master['puppetpath']}/modules2"

teardown do
  on master, "rm -rf #{master['puppetpath']}/modules2"
end

step "Install a module with relative modulepath"
on master, "cd #{master['puppetpath']}/modules2 && puppet module install pmtacceptance-nginx --modulepath=." do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['puppetpath']}/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['puppetpath']}/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['puppetpath']}/modules2/nginx ]"

step "Install a module with absolute modulepath"
on master, "test -d #{master['puppetpath']}/modules2/nginx && rm -rf #{master['puppetpath']}/modules2/nginx"
on master, puppet("module install pmtacceptance-nginx --modulepath=#{master['puppetpath']}/modules2") do
  assert_output <<-OUTPUT
    \e[mNotice: Preparing to install into #{master['puppetpath']}/modules2 ...\e[0m
    \e[mNotice: Downloading from https://forge.puppetlabs.com ...\e[0m
    \e[mNotice: Installing -- do not interrupt ...\e[0m
    #{master['puppetpath']}/modules2
    └── pmtacceptance-nginx (\e[0;36mv0.0.1\e[0m)
  OUTPUT
end
on master, "[ -d #{master['puppetpath']}/modules2/nginx ]"
