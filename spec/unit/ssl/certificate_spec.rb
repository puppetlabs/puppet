#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/ssl/certificate'

describe Puppet::SSL::Certificate do
  let :key do Puppet::SSL::Key.new("test.localdomain").generate end

  # Sign the provided cert so that it can be DER-decoded later
  def sign_wrapped_cert(cert)
    signer = Puppet::SSL::CertificateSigner.new
    signer.sign(cert.content, key)
  end

  before do
    @class = Puppet::SSL::Certificate
  end

  after do
    @class.instance_variable_set("@ca_location", nil)
  end

  it "should be extended with the Indirector module" do
    expect(@class.singleton_class).to be_include(Puppet::Indirector)
  end

  it "should indirect certificate" do
    expect(@class.indirection.name).to eq(:certificate)
  end

  it "should only support the text format" do
    expect(@class.supported_formats).to eq([:s])
  end

  describe "when converting from a string" do
    it "should create a certificate instance with its name set to the certificate subject and its content set to the extracted certificate" do
      cert = stub 'certificate',
        :subject => OpenSSL::X509::Name.parse("/CN=Foo.madstop.com"),
        :is_a? => true
      OpenSSL::X509::Certificate.expects(:new).with("my certificate").returns(cert)

      mycert = stub 'sslcert'
      mycert.expects(:content=).with(cert)

      @class.expects(:new).with("Foo.madstop.com").returns mycert

      @class.from_s("my certificate")
    end

    it "should create multiple certificate instances when asked" do
      cert1 = stub 'cert1'
      @class.expects(:from_s).with("cert1").returns cert1
      cert2 = stub 'cert2'
      @class.expects(:from_s).with("cert2").returns cert2

      expect(@class.from_multiple_s("cert1\n---\ncert2")).to eq([cert1, cert2])
    end
  end

  describe "when converting to a string" do
    before do
      @certificate = @class.new("myname")
    end

    it "should return an empty string when it has no certificate" do
      expect(@certificate.to_s).to eq("")
    end

    it "should convert the certificate to pem format" do
      certificate = mock 'certificate', :to_pem => "pem"
      @certificate.content = certificate
      expect(@certificate.to_s).to eq("pem")
    end

    it "should be able to convert multiple instances to a string" do
      cert2 = @class.new("foo")
      @certificate.expects(:to_s).returns "cert1"
      cert2.expects(:to_s).returns "cert2"

      expect(@class.to_multiple_s([@certificate, cert2])).to eq("cert1\n---\ncert2")

    end
  end

  describe "when managing instances" do

    def build_cert(opts)
      key = Puppet::SSL::Key.new('quux')
      key.generate
      csr = Puppet::SSL::CertificateRequest.new('quux')
      csr.generate(key, opts)

      raw_cert = Puppet::SSL::CertificateFactory.build('client', csr, csr.content, 14)
      @class.from_instance(raw_cert)
    end

    before do
      @certificate = @class.new("myname")
    end

    it "should have a name attribute" do
      expect(@certificate.name).to eq("myname")
    end

    it "should convert its name to a string and downcase it" do
      expect(@class.new(:MyName).name).to eq("myname")
    end

    it "should have a content attribute" do
      expect(@certificate).to respond_to(:content)
    end

    describe "#subject_alt_names" do
      it "should list all alternate names when the extension is present" do
        certificate = build_cert(:dns_alt_names => 'foo, bar,baz')
        expect(certificate.subject_alt_names).
          to match_array(['DNS:foo', 'DNS:bar', 'DNS:baz', 'DNS:quux'])
      end

      it "should return an empty list of names if the extension is absent" do
        certificate = build_cert({})
        expect(certificate.subject_alt_names).to be_empty
      end
    end

    describe "custom extensions" do
      it "returns extensions under the ppRegCertExt" do
        exts = {'pp_uuid' => 'abcdfd'}
        cert = build_cert(:extension_requests => exts)
        sign_wrapped_cert(cert)
        expect(cert.custom_extensions).to include('oid' => 'pp_uuid', 'value' => 'abcdfd')
      end

      it "returns extensions under the ppPrivCertExt" do
        exts = {'1.3.6.1.4.1.34380.1.2.1' => 'x509 :('}
        cert = build_cert(:extension_requests => exts)
        sign_wrapped_cert(cert)
        expect(cert.custom_extensions).to include('oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'x509 :(')
      end

      it "doesn't return standard extensions" do
        cert = build_cert(:dns_alt_names => 'foo')
        expect(cert.custom_extensions).to be_empty
      end

    end

    it "should return a nil expiration if there is no actual certificate" do
      @certificate.stubs(:content).returns nil

      expect(@certificate.expiration).to be_nil
    end

    it "should use the expiration of the certificate as its expiration date" do
      cert = stub 'cert'
      @certificate.stubs(:content).returns cert

      cert.expects(:not_after).returns "sometime"

      expect(@certificate.expiration).to eq("sometime")
    end

    it "should be able to read certificates from disk" do
      path = "/my/path"
      Puppet::FileSystem.expects(:read).with(path, :encoding => Encoding::ASCII).returns("my certificate")
      certificate = mock 'certificate'
      OpenSSL::X509::Certificate.expects(:new).with("my certificate").returns(certificate)
      expect(@certificate.read(path)).to equal(certificate)
      expect(@certificate.content).to equal(certificate)
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_certificate = mock 'certificate'
      real_certificate.expects(:to_text).returns "certificatetext"
      @certificate.content = real_certificate
      expect(@certificate.to_text).to eq("certificatetext")
    end

    it "should parse the old non-DER encoded extension values" do
      cert = OpenSSL::X509::Certificate.new(File.read(my_fixture("old-style-cert-exts.pem")))
      wrapped_cert = Puppet::SSL::Certificate.from_instance cert
      exts = wrapped_cert.custom_extensions

      expect(exts.find { |ext| ext['oid'] == 'pp_uuid'}['value']).to eq('I-AM-A-UUID')
      expect(exts.find { |ext| ext['oid'] == 'pp_instance_id'}['value']).to eq('i_am_an_id')
      expect(exts.find { |ext| ext['oid'] == 'pp_image_name'}['value']).to eq('i_am_an_image_name')
    end

  end
end
