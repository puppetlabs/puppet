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

  # CertProvider
  #
  # CA hierarchy
  #
  #   Test CA
  #     -> Test CA Subauthority
  #          -> signed
  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/x509/cert_provider')

  # Test CA & CRL
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Test CA Subauthority
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)

  # signed cert and key
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # encrypted key
  save(dir, 'encrypted-key.pem', signed[:private_key]) do |x509|
    x509.to_pem(OpenSSL::Cipher::AES.new(128, :CBC), 'password')
  end

  # SSLProvider
  #
  # CA hierarchy

  ca = Puppet::TestCa.new
  dir = File.join(RAKE_ROOT, 'spec/fixtures/unit/ssl/ssl_provider')

  # Test CA & CRL
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Intermediate CA & CRL
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)
  save(dir, 'intermediate.pem', inter[:cert])
  inter_crl = ca.create_crl(inter[:cert], inter[:private_key])

  # Cert and key for "signed" node
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # Cert and key for "revoked" node (issued by intermediate CA)
  revoked = ca.create_cert('revoked', inter[:cert], inter[:private_key])
  ca.revoke(revoked[:cert], inter_crl, inter[:private_key])
  save(dir, 'revoked.pem', revoked[:cert])
  save(dir, 'revoked-key.pem', revoked[:private_key])

  # Update intermediate CRL now that we've revoked
  save(dir, 'intermediate-crl.pem', inter_crl)

  # CSR and private key for "pending" node
  request = ca.create_request('pending')
  save(dir, 'request.pem', request[:csr])
  save(dir, 'request-key.pem', request[:private_key])

  # New CA, but containing the original CA's public key and extensions
  badca = ca.create_cacert('ca-bad-signature')[:cert]
  badca.public_key = ca.ca_cert.public_key
  badca.extensions = ca.ca_cert.extensions
  save(dir, 'bad-ca.pem', badca)

  # CA with with "I am not a CA" extension
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

  # same for intermediate CA
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

  # New entity cert issued by not-a-intermediate-ca
  fake_client = ca.create_cert('fake', badintconstraints, inter[:private_key])
  save(dir, 'fake.pem', fake_client[:cert])
  save(dir, 'fake-key.pem', fake_client[:private_key])

  # New intermediate CA whose public key doesn't match its signature
  badint = ca.create_intermediate_cert('intermediate-bad-signature', ca.ca_cert, ca.key)[:cert]
  key = OpenSSL::PKey::RSA.new(512)
  badint.public_key = key.public_key
  save(dir, 'bad-intermediate.pem', badint)

  # New intermediate CA issued by unknown CA
  unknown_ca = ca.create_cacert('unknown-ca')
  unknown_int = ca.create_intermediate_cert('unknown-int', unknown_ca[:cert], unknown_ca[:private_key])
  save(dir, 'unknown-intermediate.pem', unknown_int[:cert])

  # New CRL issued by an unknown CA
  unknown_crl = ca.create_crl(unknown_ca[:cert], unknown_ca[:private_key])
  save(dir, 'unknown-crl.pem', unknown_crl)

  # Modify CSR after it's signed
  tampered_csr = ca.create_request('signed')[:csr]
  tampered_csr.public_key = OpenSSL::PKey::RSA.new(1024).public_key
  save(dir, 'tampered-csr.pem', tampered_csr)

  # Modify cert after it's signed
  tampered_cert = ca.create_cert('signed', inter[:cert], inter[:private_key])[:cert]
  tampered_cert.public_key = OpenSSL::PKey::RSA.new(1024).public_key
  save(dir, 'tampered-cert.pem', tampered_cert)
end
