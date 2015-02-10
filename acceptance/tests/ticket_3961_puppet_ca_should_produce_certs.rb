test_name "#3961: puppet ca should produce certs spec"
confine :except, :platform => 'windows'

target  = "working3961.example.org"

expect = ['Signed certificate request for ca',
          'working3961.example.org has a waiting certificate request',
          'Signed certificate request for working3961.example.org',
          'Removing file Puppet::SSL::CertificateRequest working3961.example.org']

agents.each do |agent|
  scratch_ssldir = agent.tmpdir('puppet-ssl-3961')
  options = { :ssldir => scratch_ssldir, :vardir => scratch_ssldir }

  step "removing the SSL scratch_ssldir directory..."
  on(agent, "rm -rf #{scratch_ssldir}")

  step "generate a certificate in #{scratch_ssldir}"
  on(agent,puppet_cert('--trace', '--generate', target, options)) do
    expect.each do |line|
      stdout.index(line) or fail_test("missing line in output: #{line}")
    end
  end

  step "verify the certificate for #{target} exists"
  on agent, "test -f #{scratch_ssldir}/certs/#{target}.pem"

  step "verify the private key for #{target} exists"
  on agent, "grep 'BEGIN RSA PRIVATE KEY' #{scratch_ssldir}/private_keys/#{target}.pem > /dev/null 2>&1"
end
