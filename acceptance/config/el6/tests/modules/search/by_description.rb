test_name 'puppet module search should do substring matches on description'

step 'Setup'
stub_forge_on(master)

step 'Search for a module by description'
on master, puppet("module search dummy") do
  assert_equal '', stderr
  # FIXME: The Forge does not presently match against description.
#   assert_equal <<-STDOUT, stdout
# \e[mNotice: Searching https://forge.puppetlabs.com ...\e[0m
# NAME                  DESCRIPTION                  AUTHOR          KEYWORDS
# pmtacceptance-nginx   This is a dummy nginx mo...  @pmtacceptance  nginx
# pmtacceptance-thin    This is a dummy thin mod...  @pmtacceptance  ruby thin
# pmtacceptance-apollo  This is a dummy apollo m...  @pmtacceptance  stomp apollo
# pmtacceptance-java    This is a dummy java mod...  @pmtacceptance  java
# pmtacceptance-stdlib  This is a dummy stdlib m...  @pmtacceptance  stdlib libs
# pmtacceptance-git     This is a dummy git modu...  @pmtacceptance  git dvcs
# pmtacceptance-apache  This is a dummy apache m...  @pmtacceptance  apache php
# pmtacceptance-php     This is a dummy php modu...  @pmtacceptance  apache php
# pmtacceptance-geordi  This is a module that do...  @pmtacceptance  star trek
# STDOUT
end
