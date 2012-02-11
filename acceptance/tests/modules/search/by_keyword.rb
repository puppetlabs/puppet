test_name 'puppet module search should do exact keyword matches'

step 'Search for a module by keyword'
on master, puppet("module search key") do
  # Expected result: Module tagged `key` returned; module tagged `keyword` omitted
  # TODO: Assert results.
end
