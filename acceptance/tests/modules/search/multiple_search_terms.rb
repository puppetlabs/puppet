test_name 'puppet module search should handle multiple search terms sensibly'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for a module by description'
on master, puppet("module search module description") do
  # Expected result: 'module description' OR module OR description
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Search for a module by name'
on master, puppet("module search key bank") do
  # Expected result: key OR bank
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Search for multiple keywords'
on master, puppet("module search name game") do
  # Expected result: name OR game
  # TODO: Assert results.
  assert !stdout.empty?
end

step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
