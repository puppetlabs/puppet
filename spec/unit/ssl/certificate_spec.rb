require 'spec_helper'
require 'puppet/certificate_factory'

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

  it "should only support the text format" do
    expect(@class.supported_formats).to eq([:s])
  end

  describe "when converting from a string" do
    it "should create a certificate instance with its name set to the certificate subject and its content set to the extracted certificate" do
      cert = double(
        'certificate',
        :subject => OpenSSL::X509::Name.parse("/CN=Foo.madstop.com"),
        :is_a? => true
      )
      expect(OpenSSL::X509::Certificate).to receive(:new).with("my certificate").and_return(cert)

      mycert = double('sslcert')
      expect(mycert).to receive(:content=).with(cert)

      expect(@class).to receive(:new).with("Foo.madstop.com").and_return(mycert)

      @class.from_s("my certificate")
    end

    it "should create multiple certificate instances when asked" do
      cert1 = double('cert1')
      expect(@class).to receive(:from_s).with("cert1").and_return(cert1)
      cert2 = double('cert2')
      expect(@class).to receive(:from_s).with("cert2").and_return(cert2)

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
      certificate = double('certificate', :to_pem => "pem")
      @certificate.content = certificate
      expect(@certificate.to_s).to eq("pem")
    end

    it "should be able to convert multiple instances to a string" do
      cert2 = @class.new("foo")
      expect(@certificate).to receive(:to_s).and_return("cert1")
      expect(cert2).to receive(:to_s).and_return("cert2")

      expect(@class.to_multiple_s([@certificate, cert2])).to eq("cert1\n---\ncert2")

    end
  end

  describe "when managing instances" do
    def build_cert(opts)
      key = Puppet::SSL::Key.new('quux')
      key.generate
      csr = Puppet::SSL::CertificateRequest.new('quux')
      csr.generate(key, opts)

      raw_cert = Puppet::CertificateFactory.build('client', csr, csr.content, 14)
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

    describe "#subject_alt_names", :unless => RUBY_PLATFORM == 'java' do
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

    describe "custom extensions", :unless => RUBY_PLATFORM == 'java' do
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

      it "returns extensions under the ppAuthCertExt" do
        exts = {'pp_auth_role' => 'taketwo'}
        cert = build_cert(:extension_requests => exts)
        sign_wrapped_cert(cert)
        expect(cert.custom_extensions).to include('oid' => 'pp_auth_role', 'value' => 'taketwo')
      end

      it "doesn't return standard extensions" do
        cert = build_cert(:dns_alt_names => 'foo')
        expect(cert.custom_extensions).to be_empty
      end
    end

    it "should return a nil expiration if there is no actual certificate" do
      allow(@certificate).to receive(:content).and_return(nil)

      expect(@certificate.expiration).to be_nil
    end

    it "should use the expiration of the certificate as its expiration date" do
      cert = double('cert')
      allow(@certificate).to receive(:content).and_return(cert)

      expect(cert).to receive(:not_after).and_return("sometime")

      expect(@certificate.expiration).to eq("sometime")
    end

    it "should be able to read certificates from disk" do
      path = "/my/path"
      expect(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("my certificate")
      certificate = double('certificate')
      expect(OpenSSL::X509::Certificate).to receive(:new).with("my certificate").and_return(certificate)
      expect(@certificate.read(path)).to equal(certificate)
      expect(@certificate.content).to equal(certificate)
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_certificate = double('certificate')
      expect(real_certificate).to receive(:to_text).and_return("certificatetext")
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
