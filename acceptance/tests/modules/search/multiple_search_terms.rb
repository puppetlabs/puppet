test_name 'puppet module search should handle multiple search terms sensibly'

tag 'audit:low',
    'audit:unit',
    'audit:delete'

#step 'Setup'
#stub_forge_on(master)

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
