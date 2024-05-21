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
      f.write(x509.to_text)
      text = if block_given?
               yield x509
             else
               x509.to_pem
             end

      f.write(text)
    end
  end

  def generate(type, inter)
    # Create an EC key and cert, issued by "Test CA Subauthority"
    cert = ca.create_cert(type, inter[:cert], inter[:private_key], key_type: :type)
    save(dir, "#{type}.pem", cert[:cert])
    save(dir, "#{type}-key.pem", cert[:private_key])

    # Create an encrypted version of the above private key.
    save(dir, "encrypted-#{type}-key.pem", cert[:private_key]) do |x509|
      # private key password was chosen at random
      x509.to_pem(OpenSSL::Cipher::AES.new(128, :CBC), '74695716c8b6')
    end
  end

  # This task generates a PKI consisting of a root CA, intermediate CA and
  # several leaf certs. A CRL is generated for each CA. The root CA CRL is
  # empty, while the intermediate CA CRL contains the revoked cert's serial
  # number. A textual representation of each X509 object is included in the
  # fixture as a comment.
  #
  # Certs
  # =====
  #
  # ca.pem                           /CN=Test CA
  #                                   |
  # intermediate.pem                  +- /CN=Test CA Subauthority
  #                                   |   |
  # signed.pem                        |   +- /CN=signed
  # revoked.pem                       |   +- /CN=revoked
  # tampered-cert.pem                 |   +- /CN=signed (with different public key)
  # ec.pem                            |   +- /CN=ec (with EC private key)
  # oid.pem                           |   +- /CN=oid (with custom oid)
  #                                   |
  # 127.0.0.1.pem                     +- /CN=127.0.0.1 (with dns alt names)
  #                                   |
  # intermediate-agent.pem            +- /CN=Test CA Agent Subauthority
  #                                   |   |
  # pluto.pem                         |   +- /CN=pluto
  #                                   |
  # bad-int-basic-constraints.pem     +- /CN=Test CA Subauthority (bad isCA constraint)
  #
  # bad-basic-constraints.pem        /CN=Test CA (bad isCA constraint)
  #
  # unknown-ca.pem                   /CN=Unknown CA
  #                                   |
  # unknown-127.0.0.1.pem             +- /CN=127.0.0.1
  #
  # Keys
  # ====
  #
  # The RSA private key for each leaf cert is also generated. In addition,
  # `encrypted-key.pem` contains the private key for the `signed` cert.
  #
  # Requests
  # ========
  #
  # `request.pem` contains a valid CSR for /CN=pending, while `tampered_csr.pem`
  # is the same as `request.pem`, but it's public key has been replaced.
  #
  dir = File.join(RAKE_ROOT, 'spec/fixtures/ssl')

  # Create self-signed CA & key
  unknown_ca = Puppet::TestCa.new('Unknown CA')
  save(dir, 'unknown-ca.pem', unknown_ca.ca_cert)
  save(dir, 'unknown-ca-key.pem', unknown_ca.key)

  # Create an SSL cert for 127.0.0.1
  signed = unknown_ca.create_cert('127.0.0.1', unknown_ca.ca_cert, unknown_ca.key, subject_alt_names: 'DNS:127.0.0.1,DNS:127.0.0.2')
  save(dir, 'unknown-127.0.0.1.pem', signed[:cert])
  save(dir, 'unknown-127.0.0.1-key.pem', signed[:private_key])

  # Create Test CA & CRL
  ca = Puppet::TestCa.new
  save(dir, 'ca.pem', ca.ca_cert)
  save(dir, 'crl.pem', ca.ca_crl)

  # Create Intermediate CA & CRL "Test CA Subauthority" issued by "Test CA"
  inter = ca.create_intermediate_cert('Test CA Subauthority', ca.ca_cert, ca.key)
  save(dir, 'intermediate.pem', inter[:cert])
  save(dir, 'intermediate-key.pem', inter[:private_key])
  inter_crl = ca.create_crl(inter[:cert], inter[:private_key])

  # Create a leaf/entity key and cert for host "signed" and issued by "Test CA Subauthority"
  signed = ca.create_cert('signed', inter[:cert], inter[:private_key])
  save(dir, 'signed.pem', signed[:cert])
  save(dir, 'signed-key.pem', signed[:private_key])

  # Create a cert for host "renewed" and issued by "Test CA Subauthority"
  renewed = ca.create_cert('renewed', inter[:cert], inter[:private_key], reuse_key: signed[:private_key])
  save(dir, 'renewed.pem', renewed[:cert])

  # Create an encrypted version of the above private key for host "signed"
  save(dir, 'encrypted-key.pem', signed[:private_key]) do |x509|
    # private key password was chosen at random
    x509.to_pem(OpenSSL::Cipher::AES.new(128, :CBC), '74695716c8b6')
  end

  # Create an SSL cert for 127.0.0.1 with dns_alt_names
  signed = ca.create_cert('127.0.0.1', ca.ca_cert, ca.key, subject_alt_names: 'DNS:127.0.0.1,DNS:127.0.0.2')
  save(dir, '127.0.0.1.pem', signed[:cert])
  save(dir, '127.0.0.1-key.pem', signed[:private_key])

  # Create an SSL cert with extensions containing custom oids
  extensions = [
    ['1.3.6.1.4.1.34380.1.2.1.1', OpenSSL::ASN1::UTF8String.new('somevalue'), false],
  ]
  oid = ca.create_cert('oid', inter[:cert], inter[:private_key], extensions: extensions)
  save(dir, 'oid.pem', oid[:cert])
  save(dir, 'oid-key.pem', oid[:private_key])

  # Create a leaf/entity key and cert for host "revoked", issued by "Test CA Subauthority"
  # and revoke the cert
  revoked = ca.create_cert('revoked', inter[:cert], inter[:private_key])
  ca.revoke(revoked[:cert], inter_crl, inter[:private_key])
  save(dir, 'revoked.pem', revoked[:cert])
  save(dir, 'revoked-key.pem', revoked[:private_key])

  # Generate certificate and key sets for various algorithms.
  generate('ec', inter)
  generate('ed25519', inter)

  # Update intermediate CRL now that we've revoked
  save(dir, 'intermediate-crl.pem', inter_crl)

  # Create a pending request (CSR) and private key for host "pending"
  request = ca.create_request('pending')
  save(dir, 'request.pem', request[:csr])
  save(dir, 'request-key.pem', request[:private_key])

  # Create an intermediate for agent certs
  inter_agent = ca.create_intermediate_cert('Test CA Agent Subauthority', ca.ca_cert, ca.key)
  save(dir, 'intermediate-agent.pem', inter_agent[:cert])
  inter_agent_crl = ca.create_crl(inter_agent[:cert], inter_agent[:private_key])
  save(dir, 'intermediate-agent-crl.pem', inter_agent_crl)

  # Create a leaf/entity key and cert for host "pluto" and issued by "Test CA Agent Subauthority"
  pluto = ca.create_cert('pluto', inter_agent[:cert], inter_agent[:private_key])
  save(dir, 'pluto.pem', pluto[:cert])
  save(dir, 'pluto-key.pem', pluto[:private_key])

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
  tampered_csr.public_key = OpenSSL::PKey::RSA.new(2048).public_key
  save(dir, 'tampered-csr.pem', tampered_csr)

  # Create a cert issued from the real intermediate CA, but replace its
  # public key
  tampered_cert = ca.create_cert('signed', inter[:cert], inter[:private_key])[:cert]
  tampered_cert.public_key = OpenSSL::PKey::RSA.new(2048).public_key
  save(dir, 'tampered-cert.pem', tampered_cert)
end
