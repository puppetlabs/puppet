test_name 'puppet module search should do substring matches on description'

step 'Search for a module by description'
on master, puppet("module search description") do
  # Expected result: Module with a (full) description matching /description/ returned
  # TODO: Assert results.
end
