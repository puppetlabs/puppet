begin test_name "puppet module build (basic)"

step 'Setup'
on master, "mkdir -p #{master['distmoduledir']}"
on master, "mkdir -p #{master['sitemoduledir']}"
apply_manifest_on master, <<-PP
file {
  [
    '#{master['distmoduledir']}/nginx',
  ]: ensure => directory;
  '#{master['distmoduledir']}/nginx/Modulefile':
    content => 'name "puppetlabs-nginx"
version "0.0.1"
source "git://github.com/puppetlabs/puppetlabs-nginx.git"
author "Puppet Labs"
license "Apache Version 2.0"
summary "Nginx Module"
description "Nginx"
project_page "http://github.com/puppetlabs/puppetlabs-ntp"
dependency "puppetlabs/stdlib", ">= 1.0.0"
';
}
PP

step "Try to build a module with an absolute path"
on master, puppet("module build #{master['distmoduledir']}/nginx") do
  assert_output <<-OUTPUT
    \e[mNotice: Building #{master['distmoduledir']}/nginx for release\e[0m
    Module built: #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1 ]"
on master, "[ -f #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]"

step "Try to build a module without providing a path"
on master, ("cd #{master['distmoduledir']}/nginx && puppet module build") do
  assert_output <<-OUTPUT
    \e[mNotice: Building #{master['distmoduledir']}/nginx for release\e[0m
    Module built: #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz
  OUTPUT
end
on master, "[ -d #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1 ]"
on master, "[ -f #{master['distmoduledir']}/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]"

ensure step "Teardown"
  apply_manifest_on master, "file { '#{master['distmoduledir']}/nginx': ensure => absent, force => true }"
end
