test_name 'puppet module search should do exact keyword matches'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for a module by partial keyword'
on master, puppet("module search hub") do
  # Expected result: No results
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Search for a module by exact keyword'
on master, puppet("module search github") do
  # Expected result: pmtacceptance-git
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
