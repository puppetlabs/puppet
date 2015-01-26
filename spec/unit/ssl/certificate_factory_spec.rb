#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_factory'

describe Puppet::SSL::CertificateFactory do
  let :serial    do OpenSSL::BN.new('12') end
  let :name      do "example.local" end
  let :x509_name do OpenSSL::X509::Name.new([['CN', name]]) end
  let :key       do Puppet::SSL::Key.new(name).generate end
  let :csr       do
    csr = Puppet::SSL::CertificateRequest.new(name)
    csr.generate(key)
    csr
  end
  let :issuer do
    cert = Puppet::SSL::CertificateAuthority.new
    cert.generate_ca_certificate
    cert.host.certificate.content
  end

  describe "when generating the certificate" do
    it "should return a new X509 certificate" do
      expect(subject.build(:server, csr, issuer, serial)).not_to eq(
        subject.build(:server, csr, issuer, serial)
      )
    end

    it "should set the certificate's version to 2" do
      expect(subject.build(:server, csr, issuer, serial).version).to eq(2)
    end

    it "should set the certificate's subject to the CSR's subject" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.subject).to eql x509_name
    end

    it "should set the certificate's issuer to the Issuer's subject" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.issuer).to eql issuer.subject
    end

    it "should set the certificate's public key to the CSR's public key" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.public_key).to be_public
      expect(cert.public_key.to_s).to eq(csr.content.public_key.to_s)
    end

    it "should set the certificate's serial number to the provided serial number" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.serial).to eq(serial)
    end

    it "should have 24 hours grace on the start of the cert" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.not_before).to be_within(30).of(Time.now - 24*60*60)
    end

    it "should set the default TTL of the certificate to the `ca_ttl` setting" do
      Puppet[:ca_ttl] = 12
      now = Time.now.utc
      Time.expects(:now).at_least_once.returns(now)
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.not_after.to_i).to eq(now.to_i + 12)
    end

    it "should not allow a non-integer TTL" do
      [ 'foo', 1.2, Time.now, true ].each do |ttl|
        expect { subject.build(:server, csr, issuer, serial, ttl) }.to raise_error(ArgumentError)
      end
    end

    it "should respect a custom TTL for the CA" do
      now = Time.now.utc
      Time.expects(:now).at_least_once.returns(now)
      cert = subject.build(:server, csr, issuer, serial, 12)
      expect(cert.not_after.to_i).to eq(now.to_i + 12)
    end

    it "should adds an extension for the nsComment" do
      cert = subject.build(:server, csr, issuer, serial)
      expect(cert.extensions.map {|x| x.to_h }.find {|x| x["oid"] == "nsComment" }).to eq(
        { "oid"      => "nsComment",
          # Note that this output is due to a bug in OpenSSL::X509::Extensions
          # where the values of some extensions are not properly decoded
          "value"    => ".(Puppet Ruby/OpenSSL Internal Certificate",
          "critical" => false }
      )
    end

    it "should add an extension for the subjectKeyIdentifer" do
      cert = subject.build(:server, csr, issuer, serial)
      ef = OpenSSL::X509::ExtensionFactory.new(issuer, cert)
      expect(cert.extensions.map { |x| x.to_h }.find {|x| x["oid"] == "subjectKeyIdentifier" }).to eq(
        ef.create_extension("subjectKeyIdentifier", "hash", false).to_h
      )
    end


    it "should add an extension for the authorityKeyIdentifer" do
      cert = subject.build(:server, csr, issuer, serial)
      ef = OpenSSL::X509::ExtensionFactory.new(issuer, cert)
      expect(cert.extensions.map { |x| x.to_h }.find {|x| x["oid"] == "authorityKeyIdentifier" }).to eq(
        ef.create_extension("authorityKeyIdentifier", "keyid:always", false).to_h
      )
    end

    # See #2848 for why we are doing this: we need to make sure that
    # subjectAltName is set if the CSR has it, but *not* if it is set when the
    # certificate is built!
    it "should not add subjectAltNames from dns_alt_names" do
      Puppet[:dns_alt_names] = 'one, two'
      # Verify the CSR still has no extReq, just in case...
      expect(csr.request_extensions).to eq([])
      cert = subject.build(:server, csr, issuer, serial)

      expect(cert.extensions.find {|x| x.oid == 'subjectAltName' }).to be_nil
    end

    it "should add subjectAltName when the CSR requests them" do
      Puppet[:dns_alt_names] = ''

      expect = %w{one two} + [name]

      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.generate(key, :dns_alt_names => expect.join(', '))

      expect(csr.request_extensions).not_to be_nil
      expect(csr.subject_alt_names).to match_array(expect.map{|x| "DNS:#{x}"})

      cert = subject.build(:server, csr, issuer, serial)
      san = cert.extensions.find {|x| x.oid == 'subjectAltName' }
      expect(san).not_to be_nil
      expect.each do |name|
        expect(san.value).to match(/DNS:#{name}\b/i)
      end
    end

    it "can add custom extension requests" do
      csr = Puppet::SSL::CertificateRequest.new(name)
      csr.generate(key)

      csr.stubs(:request_extensions).returns([
        {'oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'some-value'},
        {'oid' => 'pp_uuid', 'value' => 'some-uuid'},
      ])

      cert = subject.build(:client, csr, issuer, serial)

      # The cert must be signed before being later DER-decoding
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(cert, key)
      wrapped_cert = Puppet::SSL::Certificate.from_instance cert

      priv_ext = wrapped_cert.custom_extensions.find {|ext| ext['oid'] == '1.3.6.1.4.1.34380.1.2.1'}
      uuid_ext = wrapped_cert.custom_extensions.find {|ext| ext['oid'] == 'pp_uuid'}

      # The expected results should be DER encoded, the Puppet cert wrapper will turn
      # these into normal strings.
      expect(priv_ext['value']).to eq 'some-value'
      expect(uuid_ext['value']).to eq 'some-uuid'
    end

    # Can't check the CA here, since that requires way more infrastructure
    # that I want to build up at this time.  We can verify the critical
    # values, though, which are non-CA certs. --daniel 2011-10-11
    { :ca            => 'CA:TRUE',
      :terminalsubca => ['CA:TRUE', 'pathlen:0'],
      :server        => 'CA:FALSE',
      :ocsp          => 'CA:FALSE',
      :client        => 'CA:FALSE',
    }.each do |name, value|
      it "should set basicConstraints for #{name} #{value.inspect}" do
        cert = subject.build(name, csr, issuer, serial)
        bc = cert.extensions.find {|x| x.oid == 'basicConstraints' }
        expect(bc).to be
        expect(bc.value.split(/\s*,\s*/)).to match_array(Array(value))
      end
    end
  end
end
