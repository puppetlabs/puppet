test_name 'puppet module search should print a reasonable message on communication errors'

confine :except, :platform => 'solaris'

step 'Setup'
stub_hosts_on(master, 'forge.puppetlabs.com' => '127.0.0.2')

step "Search against a non-existent Forge"
on master, puppet("module search yup"), :acceptable_exit_codes => [1] do
  assert_match <<-STDOUT, stdout
\e[mNotice: Searching https://forge.puppetlabs.com ...\e[0m
STDOUT
  assert_match <<-STDERR.chomp, stderr
Error: Could not connect to https://forge.puppetlabs.com
  There was a network communications problem
    The error we caught said 'Connection refused - connect(2)'
    Check your network connection and try again
STDERR
end
