# Run this rake task to generate cert fixtures used in unit tests. This should
# be run whenever new fixtures are required that derive from the existing ones
# such as to add an extension to client certs, change expiration, etc. All
# regenerated fixtures should be committed together.
desc "generate cert fixtures"
task(:gen_cert_fixtures) do
  $LOAD_PATH << File.expand_path(File.join(File.dirname(__FILE__), '../spec/lib'))
  require 'puppet/test_ca'

  def save(dir, name, x509)
    path = File.join(dir, name)
    puts "Generating #{path}"
    File.open(path, 'w') do |f|
      text = if block_given?
               yield x509
             else
               x509.to_pem
             end
      f.write(text)
    end
  end

  # CA hierarchy
  #
  #   Test CA
  #     -> Test CA Subauthority
  #          -> signed
  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/x509/cert_provider')
  FileUtils.mkdir_p(dir)

  # Test CA & CRL
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Test CA Subauthority
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)

  # signed cert and key
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # pending request, we don't need its private key
  request = ca.create_request('pending')
  save(dir, 'request.pem', request[:csr])
end
