#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate_revocation_list'

describe Puppet::SSL::CertificateRevocationList do
  before do
    ca = Puppet::SSL::CertificateAuthority.new
    ca.generate_ca_certificate
    @cert = ca.host.certificate.content
    @key = ca.host.key.content
    @class = Puppet::SSL::CertificateRevocationList
  end

  def expects_time_close_to_now(time)
    expect(time.to_i).to be_within(5*60).of(Time.now.to_i)
  end

  def expects_time_close_to_five_years(time)
    future = Time.now + Puppet::SSL::CertificateRevocationList::FIVE_YEARS
    expect(time.to_i).to be_within(5*60).of(future.to_i)
  end

  def expects_crlnumber_extension(crl, value)
    crlNumber = crl.content.extensions.find { |ext| ext.oid == "crlNumber" }

    expect(crlNumber.value).to eq(value.to_s)
    expect(crlNumber).to_not be_critical
  end

  def expects_authkeyid_extension(crl, cert)
    subjectKeyId = cert.extensions.find { |ext| ext.oid == 'subjectKeyIdentifier' }.value

    authKeyId = crl.content.extensions.find { |ext| ext.oid == "authorityKeyIdentifier" }
    expect(authKeyId.value.chomp).to eq("keyid:#{subjectKeyId}")
    expect(authKeyId).to_not be_critical
  end

  def expects_crlreason_extension(crl, reason)
    revoke = crl.content.revoked.first

    crlNumber = crl.content.extensions.find { |ext| ext.oid == "crlNumber" }
    expect(revoke.serial.to_s).to eq(crlNumber.value)

    crlReason = revoke.extensions.find { |ext| ext.oid = 'CRLReason' }
    expect(crlReason.value).to eq(reason)
    expect(crlReason).to_not be_critical
  end

  it "should only support the text format" do
    expect(@class.supported_formats).to eq([:s])
  end

  describe "when converting from a string" do
    it "deserializes a CRL" do
      crl = @class.new('foo')
      crl.generate(@cert, @key)

      new_crl = @class.from_s(crl.to_s)
      expect(new_crl.content.to_text).to eq(crl.content.to_text)
    end
  end

  describe "when an instance" do
    before do
      @crl = @class.new("whatever")
    end

    it "should always use 'crl' for its name" do
      expect(@crl.name).to eq("crl")
    end

    it "should have a content attribute" do
      expect(@crl).to respond_to(:content)
    end
  end

  describe "when generating the crl" do
    before do
      @crl = @class.new("crl")
    end

    it "should set its issuer to the subject of the passed certificate" do
      expect(@crl.generate(@cert, @key).issuer.to_s).to eq(@cert.subject.to_s)
    end

    it "should set its version to 1" do
      expect(@crl.generate(@cert, @key).version).to eq(1)
    end

    it "should create an instance of OpenSSL::X509::CRL" do
      expect(@crl.generate(@cert, @key)).to be_an_instance_of(OpenSSL::X509::CRL)
    end

    it "should add an extension for the CRL number" do
      @crl.generate(@cert, @key)

      expects_crlnumber_extension(@crl, 0)
    end

    it "should add an extension for the authority key identifier" do
      @crl.generate(@cert, @key)

      expects_authkeyid_extension(@crl, @cert)
    end

    it "returns the last update time in UTC" do
      # https://tools.ietf.org/html/rfc5280#section-5.1.2.4
      thisUpdate = @crl.generate(@cert, @key).last_update
      expect(thisUpdate).to be_utc
      expects_time_close_to_now(thisUpdate)
    end

    it "returns the next update time in UTC 5 years from now" do
      # https://tools.ietf.org/html/rfc5280#section-5.1.2.5
      nextUpdate = @crl.generate(@cert, @key).next_update
      expect(nextUpdate).to be_utc
      expects_time_close_to_five_years(nextUpdate)
    end

    it "should verify using the CA public_key" do
      expect(@crl.generate(@cert, @key).verify(@key.public_key)).to be_truthy
    end

    it "should set the content to the generated crl" do
      # this test shouldn't be needed since we test the return of generate() which should be the content field
      @crl.generate(@cert, @key)
      expect(@crl.content).to be_an_instance_of(OpenSSL::X509::CRL)
    end
  end

  # This test suite isn't exactly complete, because the
  # SSL stuff is very complicated.  It just hits the high points.
  describe "when revoking a certificate" do
    before do
      @crl = @class.new("crl")
      @crl.generate(@cert, @key)

      Puppet::SSL::CertificateRevocationList.indirection.stubs :save
    end

    it "should require a serial number and the CA's private key" do
      expect { @crl.revoke }.to raise_error(ArgumentError)
    end

    it "should mark the CRL as updated at a time that makes it valid now" do
      @crl.revoke(1, @key)

      expects_time_close_to_now(@crl.content.last_update)
    end

    it "should mark the CRL valid for five years" do
      @crl.revoke(1, @key)

      expects_time_close_to_five_years(@crl.content.next_update)
    end

    it "should sign the CRL with the CA's private key and a digest instance" do
      @crl.content.expects(:sign).with { |key, digest| key == @key and digest.is_a?(OpenSSL::Digest::SHA1) }
      @crl.revoke(1, @key)
    end

    it "should save the CRL" do
      Puppet::SSL::CertificateRevocationList.indirection.expects(:save).with(@crl, nil)
      @crl.revoke(1, @key)
    end

    it "adds the crlNumber extension containing the serial number" do
      serial = 1
      @crl.revoke(serial, @key)

      expects_crlnumber_extension(@crl, serial)
    end

    it "adds the CA cert's subjectKeyId as the authorityKeyIdentifier to the CRL" do
      @crl.revoke(1, @key)

      expects_authkeyid_extension(@crl, @cert)
    end

    it "adds a non-critical CRL reason specifying key compromise by default" do
      # https://tools.ietf.org/html/rfc5280#section-5.3.1
      serial = 1
      @crl.revoke(serial, @key)

      expects_crlreason_extension(@crl, 'Key Compromise')
    end

    it "allows alternate reasons to be specified" do
      serial = 1
      @crl.revoke(serial, @key, OpenSSL::OCSP::REVOKED_STATUS_CACOMPROMISE)

      expects_crlreason_extension(@crl, 'CA Compromise')
    end
  end
end
