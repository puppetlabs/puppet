begin test_name 'puppet module search should print a reasonable message on communication errors'

step 'Stub forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ip => '127.0.0.2' }"

step "Search against a non-existent Forge"
on master, puppet("module search yup"), :acceptable_exit_codes => [1] do
  assert_match <<-STDOUT, stdout
Searching https://forge.puppetlabs.com ...
STDOUT
  assert_match <<-STDERR.chomp, stderr
Error: Could not connect to https://forge.puppetlabs.com
  There was a network communications problem
    Check your network connection and try again
STDERR
end

ensure step 'Unstub forge.puppetlabs.com'
apply_manifest_on master, "host { 'forge.puppetlabs.com': ensure => absent }"
end
