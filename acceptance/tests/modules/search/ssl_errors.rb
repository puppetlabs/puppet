begin test_name 'puppet module search should print a reasonable message on ssl errors'

step "Search against a website where the certificate is not signed by a public authority"

# This might seem silly, but a master has a self-signed certificate and is a
# cheap way of testing against a web server without a publicly signed cert
with_master_running_on(master) do
  on master, puppet("module search yup --module_repository=https://#{master}:8140"), :acceptable_exit_codes => [1] do
    assert_match <<-STDOUT, stdout
Searching https://#{master}:8140 ...
STDOUT
    assert_match <<-STDERR.chomp, stderr
Error: Unable to verify the SSL certificate at https://#{master}:8140
  This could be because the certificate is invalid or that the CA bundle
  installed with your version of OpenSSL is not available, not valid or
  not up to date.
STDERR
end

end

ensure step 'Remove fake forge hostname'
apply_manifest_on master, "host { 'fake.fakeforge.com': ensure => absent }"
end
