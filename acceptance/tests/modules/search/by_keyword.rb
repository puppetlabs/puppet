begin test_name 'puppet module search should do exact keyword matches'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.com')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

step 'Search for a module by exact keyword'
on master, puppet("module search github") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
NAME               DESCRIPTION                    AUTHOR          KEYWORDS      
pmtacceptance-git  This is a dummy git module...  @pmtacceptance  git github    
STDOUT
end

# FIXME: The Forge presently matches partial keywords.
# step 'Search for a module by partial keyword'
# on master, puppet("module search hub") do
#   assert_equal '', stderr
#   assert_equal <<-STDOUT, stdout
# Searching http://forge.puppetlabs.com ...
# No results found for 'hub'.
# STDOUT
# end

ensure step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
end
