test_name 'puppet module search should handle multiple search terms sensibly'

step 'Search for a module by description'
on master, puppet("module search module description") do
  # Expected result: 'module description' OR module OR description
  # TODO: Assert results.
end

step 'Search for a module by name'
on master, puppet("module search key bank") do
  # Expected result: key OR bank
  # TODO: Assert results.
end

step 'Search for multiple keywords'
on master, puppet("module search name game") do
  # Expected result: name OR game
  # TODO: Assert results.
end
