# Run this rake task to generate cert fixtures used in unit tests. This should
# be run whenever new fixtures are required that derive from the existing ones
# such as to add an extension to client certs, change expiration, etc. All
# regenerated fixtures should be committed together.
desc "Generate cert test fixtures"
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

  # CertProvider fixtures
  #
  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/x509/cert_provider')
  FileUtils.mkdir_p(dir)

  # Create Test CA & CRL
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Create intermediate CA "Test CA Subauthority" issued by "Test CA"
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)

  # Create a leaf/entity key and cert for host "signed" and issued by "Test CA Subauthority"
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # Create an encrypted version of the above private key for host "signed"
  save(dir, 'encrypted-key.pem', signed[:private_key]) do |x509|
    # private key password was chosen at random
    x509.to_pem(OpenSSL::Cipher::AES.new(128, :CBC), '74695716c8b6')
  end

  # Create an SSL cert for 127.0.0.1 and dns_alt_names
  signed = ca.create_cert('127.0.0.1', ca.ca_cert, ca.key, subject_alt_names: 'DNS:127.0.0.1,DNS:127.0.0.2')
  save(dir, 'localhost.pem', signed[:cert])
  save(dir, 'localhost-key.pem', signed[:private_key])

  # Create a pending request (CSR), we don't need to save its private key
  request = ca.create_request('pending')
  save(dir, 'request.pem', request[:csr])

  # SSLProvider fixtures
  #
  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/ssl/ssl_provider')
  FileUtils.mkdir_p(dir)

  # Create Test CA & CRL
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Create Intermediate CA & CRL "Test CA Subauthority" issued by "Test CA"
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)
  save(dir, 'intermediate.pem', inter[:cert])
  inter_crl = ca.create_crl(inter[:cert], inter[:private_key])

  # Create a leaf/entity key and cert for host "signed" and issued by "Test CA Subauthority"
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # Create a leaf/entity key and cert for host "revoked", issued by "Test CA Subauthority"
  # and revoke the cert
  revoked = ca.create_cert('revoked', inter[:cert], inter[:private_key])
  ca.revoke(revoked[:cert], inter_crl, inter[:private_key])
  save(dir, 'revoked.pem', revoked[:cert])
  save(dir, 'revoked-key.pem', revoked[:private_key])

  # Update intermediate CRL now that we've revoked
  save(dir, 'intermediate-crl.pem', inter_crl)

  # Create a pending request (CSR) and private key for host "pending"
  request = ca.create_request('pending')
  save(dir, 'request.pem', request[:csr])
  save(dir, 'request-key.pem', request[:private_key])

  # Create a new root CA cert, but change the "isCA" basic constraint.
  # It should not be trusted to act as a CA.
  badconstraints = ca.create_cacert('Test CA')[:cert]
  badconstraints.public_key = ca.ca_cert.public_key
  badconstraints.extensions = []
  ca.ca_cert.extensions.each do |ext|
    if ext.oid == 'basicConstraints'
      ef = OpenSSL::X509::ExtensionFactory.new
      badconstraints.add_extension(ef.create_extension("basicConstraints","CA:FALSE", true))
    else
      badconstraints.add_extension(ext)
    end
  end
  badconstraints.sign(ca.key, OpenSSL::Digest::SHA256.new)
  save(dir, 'bad-basic-constraints.pem', badconstraints)

  # Same as above, but create a new intermediate CA
  badintconstraints = inter[:cert].dup
  badintconstraints.public_key = inter[:cert].public_key
  badintconstraints.extensions = []
  inter[:cert].extensions.each do |ext|
    if ext.oid == 'basicConstraints'
      ef = OpenSSL::X509::ExtensionFactory.new
      badintconstraints.add_extension(ef.create_extension("basicConstraints","CA:FALSE", true))
    else
      badintconstraints.add_extension(ext)
    end
  end
  badintconstraints.sign(ca.key, OpenSSL::Digest::SHA256.new)
  save(dir, 'bad-int-basic-constraints.pem', badintconstraints)

  # Create a request, but replace its public key after it's signed
  tampered_csr = ca.create_request('signed')[:csr]
  tampered_csr.public_key = OpenSSL::PKey::RSA.new(1024).public_key
  save(dir, 'tampered-csr.pem', tampered_csr)

  # Create a cert issued from the real intermediate CA, but replace its
  # public key
  tampered_cert = ca.create_cert('signed', inter[:cert], inter[:private_key])[:cert]
  tampered_cert.public_key = OpenSSL::PKey::RSA.new(1024).public_key
  save(dir, 'tampered-cert.pem', tampered_cert)

  # Verifier fixtures
  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/ssl/verifier')
  FileUtils.mkdir_p(dir)

  cert = ca.create_cert('foo', ca.ca_cert, ca.key, subject_alt_names: 'DNS:foo,DNS:bar,DNS:baz')[:cert]
  save(dir, 'foobarbaz.pem', cert)
end
