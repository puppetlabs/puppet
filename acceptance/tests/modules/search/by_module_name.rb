test_name 'puppet module search should do substring matches on module name'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for modules by partial name'
on master, puppet("module search acceptance-a") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS
pmtacceptance-apollo  This is a dummy apollo m...  @pmtacceptance  stomp apollo
pmtacceptance-apache  This is a dummy apache m...  @pmtacceptance  apache php
STDOUT
end

step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
