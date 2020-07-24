require 'spec_helper'

require 'puppet/ssl/certificate_request'
require 'puppet/ssl/key'

describe Puppet::SSL::CertificateRequest do
  let(:request) { described_class.new("myname") }
  let(:key) {
    k = Puppet::SSL::Key.new("myname")
    k.generate
    k
  }

  it "should use any provided name as its name" do
    expect(described_class.new("myname").name).to eq("myname")
  end

  it "should only support the text format" do
    expect(described_class.supported_formats).to eq([:s])
  end

  describe "when converting from a string" do
    it "should create a CSR instance with its name set to the CSR subject and its content set to the extracted CSR" do
      csr = double('csr',
        :subject => OpenSSL::X509::Name.parse("/CN=Foo.madstop.com"),
        :is_a? => true)
      expect(OpenSSL::X509::Request).to receive(:new).with("my csr").and_return(csr)

      mycsr = double('sslcsr')
      expect(mycsr).to receive(:content=).with(csr)

      expect(described_class).to receive(:new).with("Foo.madstop.com").and_return(mycsr)

      described_class.from_s("my csr")
    end
  end

  describe "when managing instances" do
    it "should have a name attribute" do
      expect(request.name).to eq("myname")
    end

    it "should downcase its name" do
      expect(described_class.new("MyName").name).to eq("myname")
    end

    it "should have a content attribute" do
      expect(request).to respond_to(:content)
    end

    it "should be able to read requests from disk" do
      path = "/my/path"
      expect(Puppet::FileSystem).to receive(:read).with(path, :encoding => Encoding::ASCII).and_return("my request")
      my_req = double('request')
      expect(OpenSSL::X509::Request).to receive(:new).with("my request").and_return(my_req)
      expect(request.read(path)).to equal(my_req)
      expect(request.content).to equal(my_req)
    end

    it "should return an empty string when converted to a string with no request" do
      expect(request.to_s).to eq("")
    end

    it "should convert the request to pem format when converted to a string", :unless => RUBY_PLATFORM == 'java' do
      request.generate(key)
      expect(request.to_s).to eq(request.content.to_pem)
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_request = double('request')
      expect(real_request).to receive(:to_text).and_return("requesttext")
      request.content = real_request
      expect(request.to_text).to eq("requesttext")
    end
  end

  describe "when generating", :unless => RUBY_PLATFORM == 'java' do
    it "should use the content of the provided key if the key is a Puppet::SSL::Key instance" do
      request.generate(key)
      expect(request.content.verify(key.content.public_key)).to be_truthy
    end

    it "should set the subject to [CN, name]" do
      request.generate(key)
      expect(request.content.subject).to eq OpenSSL::X509::Name.new([['CN', key.name]])
    end

    it "should set the version to 0" do
      request.generate(key)
      expect(request.content.version).to eq(0)
    end

    it "should set the public key to the provided key's public key" do
      request.generate(key)
      # The openssl bindings do not define equality on keys so we use to_s
      expect(request.content.public_key.to_s).to eq(key.content.public_key.to_s)
    end

    context "without subjectAltName / dns_alt_names" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      ["extreq", "msExtReq"].each do |name|
        it "should not add any #{name} attribute" do
          request.generate(key)
          expect(request.content.attributes.find do |attr|
            attr.oid == name
          end).not_to be
        end

        it "should return no subjectAltNames" do
          request.generate(key)
          expect(request.subject_alt_names).to be_empty
        end
      end
    end

    context "with dns_alt_names" do
      before :each do
        Puppet[:dns_alt_names] = "one, two, three"
      end

      ["extreq", "msExtReq"].each do |name|
        it "should not add any #{name} attribute" do
          request.generate(key)
          expect(request.content.attributes.find do |attr|
            attr.oid == name
          end).not_to be
        end

        it "should return no subjectAltNames" do
          request.generate(key)
          expect(request.subject_alt_names).to be_empty
        end
      end
    end

    context "with subjectAltName to generate request" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      it "should add an extreq attribute" do
        request.generate(key, :dns_alt_names => 'one, two')
        extReq = request.content.attributes.find do |attr|
          attr.oid == 'extReq'
        end

        expect(extReq).to be
        extReq.value.value.all? do |x|
          x.value.all? do |y|
            expect(y.value[0].value).to eq("subjectAltName")
          end
        end
      end

      it "should return the subjectAltName values" do
        request.generate(key, :dns_alt_names => 'one,two')
        expect(request.subject_alt_names).to match_array(["DNS:myname", "DNS:one", "DNS:two"])
      end
    end

    context "with DNS and IP SAN specified" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      it "should return the subjectAltName values" do
        request.generate(key, :dns_alt_names => 'DNS:foo, bar, IP:172.16.254.1')
        expect(request.subject_alt_names).to match_array(["DNS:bar", "DNS:foo", "DNS:myname", "IP Address:172.16.254.1"])
      end
    end

    context "with custom CSR attributes" do

      it "adds attributes with single values" do
        csr_attributes = {
          '1.3.6.1.4.1.34380.1.2.1' => 'CSR specific info',
          '1.3.6.1.4.1.34380.1.2.2' => 'more CSR specific info',
        }

        request.generate(key, :csr_attributes => csr_attributes)

        attrs = request.custom_attributes
        expect(attrs).to include({'oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'CSR specific info'})
        expect(attrs).to include({'oid' => '1.3.6.1.4.1.34380.1.2.2', 'value' => 'more CSR specific info'})
      end

      ['extReq', '1.2.840.113549.1.9.14'].each do |oid|
        it "doesn't overwrite standard PKCS#9 CSR attribute '#{oid}'" do
          expect do
            request.generate(key, :csr_attributes => {oid => 'data'})
          end.to raise_error ArgumentError, /Cannot specify.*#{oid}/
        end
      end

      ['msExtReq', '1.3.6.1.4.1.311.2.1.14'].each do |oid|
        it "doesn't overwrite Microsoft extension request OID '#{oid}'" do
          expect do
            request.generate(key, :csr_attributes => {oid => 'data'})
          end.to raise_error ArgumentError, /Cannot specify.*#{oid}/
        end
      end

      it "raises an error if an attribute cannot be created" do
        csr_attributes = { "thats.no.moon" => "death star" }

        expect do
          request.generate(key, :csr_attributes => csr_attributes)
        end.to raise_error Puppet::Error, /Cannot create CSR with attribute thats\.no\.moon: first num too large/
      end

      it "should support old non-DER encoded extensions" do
        csr = OpenSSL::X509::Request.new(File.read(my_fixture("old-style-cert-request.pem")))
        wrapped_csr = Puppet::SSL::CertificateRequest.from_instance csr
        exts = wrapped_csr.request_extensions()

        expect(exts.find { |ext| ext['oid'] == 'pp_uuid' }['value']).to eq('I-AM-A-UUID')
        expect(exts.find { |ext| ext['oid'] == 'pp_instance_id' }['value']).to eq('i_am_an_id')
        expect(exts.find { |ext| ext['oid'] == 'pp_image_name' }['value']).to eq('i_am_an_image_name')
      end
    end

    context "with extension requests" do
      let(:extension_data) do
        {
          '1.3.6.1.4.1.34380.1.1.31415' => 'pi',
          '1.3.6.1.4.1.34380.1.1.2718'  => 'e',
        }
      end

      it "adds an extreq attribute to the CSR" do
        request.generate(key, :extension_requests => extension_data)

        exts = request.content.attributes.select { |attr| attr.oid = 'extReq' }
        expect(exts.length).to eq(1)
      end

      it "adds an extension for each entry in the extension request structure" do
        request.generate(key, :extension_requests => extension_data)

        exts = request.request_extensions

        expect(exts).to include('oid' => '1.3.6.1.4.1.34380.1.1.31415', 'value' => 'pi')
        expect(exts).to include('oid' => '1.3.6.1.4.1.34380.1.1.2718', 'value' => 'e')
      end

      it "defines the extensions as non-critical" do
        request.generate(key, :extension_requests => extension_data)
        request.request_extensions.each do |ext|
          expect(ext['critical']).to be_falsey
        end
      end

      it "rejects the subjectAltNames extension" do
        san_names = ['subjectAltName', '2.5.29.17']
        san_field = 'DNS:first.tld, DNS:second.tld'

        san_names.each do |name|
          expect do
            request.generate(key, :extension_requests => {name => san_field})
          end.to raise_error Puppet::Error, /conflicts with internally used extension/
        end
      end

      it "merges the extReq attribute with the subjectAltNames extension" do
        request.generate(key,
                         :dns_alt_names => 'first.tld, second.tld',
                         :extension_requests => extension_data)
        exts = request.request_extensions

        expect(exts).to include('oid' => '1.3.6.1.4.1.34380.1.1.31415', 'value' => 'pi')
        expect(exts).to include('oid' => '1.3.6.1.4.1.34380.1.1.2718', 'value' => 'e')
        expect(exts).to include('oid' => 'subjectAltName', 'value' => 'DNS:first.tld, DNS:myname, DNS:second.tld')

        expect(request.subject_alt_names).to eq ['DNS:first.tld', 'DNS:myname', 'DNS:second.tld']
      end

      it "raises an error if the OID could not be created" do
        exts = {"thats.no.moon" => "death star"}
        expect do
          request.generate(key, :extension_requests => exts)
        end.to raise_error Puppet::Error, /Cannot create CSR with extension request thats\.no\.moon.*: first num too large/
      end
    end

    it "should sign the csr with the provided key" do
      request.generate(key)
      expect(request.content.verify(key.content.public_key)).to be_truthy
    end

    it "should verify the generated request using the public key" do
      # Stupid keys don't have a competent == method.
      expect_any_instance_of(OpenSSL::X509::Request).to receive(:verify) do |public_key|
        public_key.to_s == key.content.public_key.to_s
      end.and_return(true)
      request.generate(key)
    end

    it "should fail if verification fails" do
      expect_any_instance_of(OpenSSL::X509::Request).to receive(:verify) do |public_key|
        public_key.to_s == key.content.public_key.to_s
      end.and_return(false)

      expect do
        request.generate(key)
      end.to raise_error(Puppet::Error, /CSR sign verification failed/)
    end

    it "should log the fingerprint" do
      allow_any_instance_of(Puppet::SSL::Digest).to receive(:to_hex).and_return("FINGERPRINT")
      allow(Puppet).to receive(:info)
      expect(Puppet).to receive(:info).with(/FINGERPRINT/)
      request.generate(key)
    end

    it "should return the generated request" do
      generated = request.generate(key)
      expect(generated).to be_a(OpenSSL::X509::Request)
      expect(generated).to be(request.content)
    end

    it "should use SHA1 to sign the csr when SHA256 isn't available" do
      csr = OpenSSL::X509::Request.new
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA256").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA1").and_return(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      expect(csr.verify(key.content)).to be_truthy
    end

    # Attempts to use SHA512 and SHA384 for signing certificates don't seem to work
    # So commenting it out till it is sorted out
    # The problem seems to be with the ability to sign a CSR when using either of
    # these hash algorithms
    pending "should use SHA512 to sign the csr when SHA256 and SHA1 aren't available" do
      csr = OpenSSL::X509::Request.new
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA256").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA1").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA512").and_return(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      expect(csr.verify(key.content)).to be_truthy
    end

    # Attempts to use SHA512 and SHA384 for signing certificates don't seem to work
    # So commenting it out till it is sorted out
    # The problem seems to be with the ability to sign a CSR when using either of
    # these hash algorithms
    pending "should use SHA384 to sign the csr when SHA256/SHA1/SHA512 aren't available" do
      csr = OpenSSL::X509::Request.new
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA256").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA1").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA512").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA384").and_return(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      expect(csr.verify(key.content)).to be_truthy
    end

    it "should use SHA224 to sign the csr when SHA256/SHA1/SHA512/SHA384 aren't available" do
      csr = OpenSSL::X509::Request.new
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA256").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA1").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA512").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA384").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA224").and_return(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      expect(csr.verify(key.content)).to be_truthy
    end

    it "should raise an error if neither SHA256/SHA1/SHA512/SHA384/SHA224 are available" do
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA256").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA1").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA512").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA384").and_return(false)
      expect(OpenSSL::Digest).to receive(:const_defined?).with("SHA224").and_return(false)
      expect {
        Puppet::SSL::CertificateSigner.new
      }.to raise_error(Puppet::Error)
    end
  end
end
