test_name 'puppet module search should do substring matches on description'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for a module by description'
on master, puppet("module search dummy") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS
pmtacceptance-nginx   This is a dummy nginx mo...  @pmtacceptance  nginx
pmtacceptance-thin    This is a dummy thin mod...  @pmtacceptance  ruby thin
pmtacceptance-apollo  This is a dummy apollo m...  @pmtacceptance  stomp apollo
pmtacceptance-java    This is a dummy java mod...  @pmtacceptance  java
pmtacceptance-stdlib  This is a dummy stdlib m...  @pmtacceptance  stdlib libs
pmtacceptance-git     This is a dummy git modu...  @pmtacceptance  git dvcs
pmtacceptance-apache  This is a dummy apache m...  @pmtacceptance  apache php
pmtacceptance-php     This is a dummy php modu...  @pmtacceptance  apache php
pmtacceptance-geordi  This is a module that do...  @pmtacceptance  star trek
STDOUT
  assert !stdout.empty?
end

step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
