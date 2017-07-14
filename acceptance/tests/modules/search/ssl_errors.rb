begin test_name 'puppet module search should print a reasonable message on ssl errors'

tag 'audit:low',
    'audit:unit'

step "Search against a website where the certificate is not signed by a public authority"

# This might seem silly, but a master has a self-signed certificate and is a
# cheap way of testing against a web server without a publicly signed cert
with_puppet_running_on master, {} do
  on master, puppet("module search yup --module_repository=https://#{master}:8140"), :acceptable_exit_codes => [1] do
    assert_match <<-STDOUT, stdout
\e[mNotice: Searching https://#{master}:8140 ...\e[0m
STDOUT
    assert_match <<-STDERR.chomp, stderr
Error: Could not connect via HTTPS to https://#{master}:8140
  Unable to verify the SSL certificate
    The certificate may not be signed by a valid CA
    The CA bundle included with OpenSSL may not be valid or up to date
STDERR
end

end

ensure step 'Remove fake forge hostname'
apply_manifest_on master, "host { 'fake.fakeforge.com': ensure => absent }"
end
