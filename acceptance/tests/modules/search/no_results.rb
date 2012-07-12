begin test_name 'puppet module search should print a reasonable message for no results'

step 'Stub forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step "Search for a module that doesn't exist"
on master, puppet("module search module_not_appearing_in_this_forge") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching https://forge.puppetlabs.com ...
No results found for 'module_not_appearing_in_this_forge'.
STDOUT
end

ensure step 'Unstub forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
end
