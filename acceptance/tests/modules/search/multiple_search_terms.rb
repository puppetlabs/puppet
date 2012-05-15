begin test_name 'puppet module search should handle multiple search terms sensibly'

step 'Stub http://forge.puppetlabs.com'
require 'resolv'; ip = Resolv.getaddress('forge-dev.puppetlabs.lan')
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '#{ip}' }"

# FIXME: The Forge doesn't properly handle multi-term searches.
# step 'Search for a module by description'
# on master, puppet("module search 'notice here'") do
#   assert stdout !~ /'notice here'/
# end
#
# step 'Search for a module by name'
# on master, puppet("module search 'ance-geo ance-std'") do
#   assert stdout !~ /'ance-geo ance-std'/
# end
#
# step 'Search for multiple keywords'
# on master, puppet("module search 'star trek'") do
#   assert stdout !~ /'star trek'/
# end

ensure step 'Unstub http://forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
end
