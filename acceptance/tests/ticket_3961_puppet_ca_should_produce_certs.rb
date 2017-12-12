test_name "#3961: puppet ca should produce certs spec"
confine :except, :platform => 'windows'
confine :except, :platform => /^eos-/

tag 'audit:high',        # basic CA functionality
    'audit:refactor',     # Use block style `test_name`
    'audit:integration',
    'server'

target  = "working3961.example.org"

expect = ['Signed certificate request for ca',
          'working3961.example.org has a waiting certificate request',
          'Signed certificate request for working3961.example.org',
          'Removing file Puppet::SSL::CertificateRequest working3961.example.org']

agents.each do |agent|
  scratch = agent.tmpdir('puppet-ssl-3961')
  options = { :confdir => scratch, :vardir => scratch }

  step "removing the SSL scratch directory..."
  on(agent, "rm -rf #{scratch}")

  step "generate a certificate in #{scratch}"
  on(agent,puppet_cert('--trace', '--generate', target, options)) do
    expect.each do |line|
      stdout.index(line) or fail_test("missing line in output: #{line}")
    end
  end

  step "verify the certificate for #{target} exists"
  on agent, "test -f #{scratch}/ssl/certs/#{target}.pem"

  step "verify the private key for #{target} exists"
  if on(agent, facter("fips_enabled")).stdout =~ /true/
    on agent, "grep 'BEGIN PRIVATE KEY' #{scratch}/ssl/private_keys/#{target}.pem > /dev/null 2>&1"
  else
    on agent, "grep 'BEGIN RSA PRIVATE KEY' #{scratch}/ssl/private_keys/#{target}.pem > /dev/null 2>&1"
  end
end
