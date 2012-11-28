begin test_name "puppet module build (basic)"

step 'Setup'
apply_manifest_on master, "file { ['/etc/puppet/modules', '/usr/share/puppet/modules']: ensure => directory, recurse => true, purge => true, force => true }"
apply_manifest_on master, <<-PP
file {
  [
    '/etc/puppet/modules/nginx',
  ]: ensure => directory;
  '/etc/puppet/modules/nginx/Modulefile':
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
on master, puppet("module build /etc/puppet/modules/nginx") do
  assert_output <<-OUTPUT
    \e[mNotice: Building /etc/puppet/modules/nginx for release\e[0m
    Module built: /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1 ]'
on master, '[ -f /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]'

step "Try to build a module without providing a path"
on master, ("cd /etc/puppet/modules/nginx && puppet module build") do
  assert_output <<-OUTPUT
    \e[mNotice: Building /etc/puppet/modules/nginx for release\e[0m
    Module built: /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz
  OUTPUT
end
on master, '[ -d /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1 ]'
on master, '[ -f /etc/puppet/modules/nginx/pkg/puppetlabs-nginx-0.0.1.tar.gz ]'

ensure step "Teardown"
apply_manifest_on master, "file { '/etc/puppet/modules': recurse => true, purge => true, force => true }"
end
