test_name 'puppet module search should print a reasonable message for no results'

step 'Setup'
stub_forge_on(master)

step "Search for a module that doesn't exist"
on master, puppet("module search module_not_appearing_in_this_forge") do
  assert_equal '', stderr
  assert_equal <<-STDOUT, stdout
\e[mNotice: Searching https://forge.puppetlabs.com ...\e[0m
No results found for 'module_not_appearing_in_this_forge'.
STDOUT
end
