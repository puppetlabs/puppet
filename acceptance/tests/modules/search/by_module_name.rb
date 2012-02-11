test_name 'puppet module search should do substring matches on module name'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for a module by partial name'
on master, puppet("module search name") do
  # Expected result: Module named module-names returned
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
