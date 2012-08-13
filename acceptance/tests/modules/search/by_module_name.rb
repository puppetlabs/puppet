test_name 'Searching for modules by part of the name'

step 'Setup'
stub_forge_on(master)

step 'Search for modules by partial name'
on master, puppet("module search geordi") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS     
pmtacceptance-\e[0;32mgeordi\e[0m  This is a module that do...  @pmtacceptance  star trek    
STDOUT
end

# FIXME: The Forge does not presently support matches by dashed full name.
# step 'Search for modules by partial full name (dashed)'
# on master, puppet("module search tance-ge") do
#   assert_equal '', stderr
#   assert_equal <<-STDOUT, stdout
# Searching http://forge.puppetlabs.com ...
# NAME                  DESCRIPTION                  AUTHOR          KEYWORDS
# pmtacceptance-geordi  This is a module that do...  @pmtacceptance  star trek
# STDOUT
# end

step 'Search for modules by partial full name (slashed)'
on master, puppet("module search tance/ge") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
NAME                  DESCRIPTION                  AUTHOR          KEYWORDS     
pmtaccep\e[0;32mtance-ge\e[0mordi  This is a module that do...  @pmtacceptance  star trek    
STDOUT
end
