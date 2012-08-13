test_name 'puppet module search should print a reasonable message on communication errors'

step 'Setup'
stub_hosts_on(master, 'forge.puppetlabs.com' => '127.0.0.2')

step "Search against a non-existent Forge"
on master, puppet("module search yup"), :acceptable_exit_codes => [1] do
  assert_match <<-STDOUT, stdout
Searching http://forge.puppetlabs.com ...
STDOUT
  assert_match <<-STDERR, stderr
Error: Could not connect to http://forge.puppetlabs.com
  There was a network communications problem
    Check your network connection and try again
STDERR
end
