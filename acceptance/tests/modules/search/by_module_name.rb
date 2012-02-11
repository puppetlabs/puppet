test_name 'puppet module search should do substring matches on module name'

step 'Search for a module by partial name'
on master, puppet("module search name") do
  # Expected result: Module named module-names returned
  # TODO: Assert results.
end
