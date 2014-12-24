#! /usr/bin/env ruby
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


  it "should be extended with the Indirector module" do
    expect(described_class.singleton_class).to be_include(Puppet::Indirector)
  end

  it "should indirect certificate_request" do
    expect(described_class.indirection.name).to eq(:certificate_request)
  end

  it "should use any provided name as its name" do
    expect(described_class.new("myname").name).to eq("myname")
  end

  it "should only support the text format" do
    expect(described_class.supported_formats).to eq([:s])
  end

  describe "when converting from a string" do
    it "should create a CSR instance with its name set to the CSR subject and its content set to the extracted CSR" do
      csr = stub 'csr',
        :subject => OpenSSL::X509::Name.parse("/CN=Foo.madstop.com"),
        :is_a? => true
      OpenSSL::X509::Request.expects(:new).with("my csr").returns(csr)

      mycsr = stub 'sslcsr'
      mycsr.expects(:content=).with(csr)

      described_class.expects(:new).with("Foo.madstop.com").returns mycsr

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
      File.expects(:read).with(path).returns("my request")
      my_req = mock 'request'
      OpenSSL::X509::Request.expects(:new).with("my request").returns(my_req)
      expect(request.read(path)).to equal(my_req)
      expect(request.content).to equal(my_req)
    end

    it "should return an empty string when converted to a string with no request" do
      expect(request.to_s).to eq("")
    end

    it "should convert the request to pem format when converted to a string" do
      request.generate(key)
      expect(request.to_s).to eq(request.content.to_pem)
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_request = mock 'request'
      real_request.expects(:to_text).returns "requesttext"
      request.content = real_request
      expect(request.to_text).to eq("requesttext")
    end
  end

  describe "when generating" do
    it "should use the content of the provided key if the key is a Puppet::SSL::Key instance" do
      request.generate(key)
      expect(request.content.verify(key.content.public_key)).to be_truthy
    end

    it "should set the subject to [CN, name]" do
      request.generate(key)
      # OpenSSL::X509::Name only implements equality as `eql?`
      expect(request.content.subject).to eql OpenSSL::X509::Name.new([['CN', key.name]])
    end

    it "should set the CN to the :ca_name setting when the CSR is for a CA" do
      Puppet[:ca_name] = "mycertname"
      request = described_class.new(Puppet::SSL::CA_NAME).generate(key)
      expect(request.subject).to eql OpenSSL::X509::Name.new([['CN', Puppet[:ca_name]]])
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
        end.to raise_error Puppet::Error, /Cannot create CSR with extension request thats\.no\.moon: first num too large/
      end
    end

    it "should sign the csr with the provided key" do
      request.generate(key)
      expect(request.content.verify(key.content.public_key)).to be_truthy
    end

    it "should verify the generated request using the public key" do
      # Stupid keys don't have a competent == method.
      OpenSSL::X509::Request.any_instance.expects(:verify).with { |public_key|
        public_key.to_s == key.content.public_key.to_s
      }.returns true
      request.generate(key)
    end

    it "should fail if verification fails" do
      OpenSSL::X509::Request.any_instance.expects(:verify).with { |public_key|
        public_key.to_s == key.content.public_key.to_s
      }.returns false

      expect {
        request.generate(key)
      }.to raise_error(Puppet::Error, /CSR sign verification failed/)
    end

    it "should log the fingerprint" do
      Puppet::SSL::Digest.any_instance.stubs(:to_hex).returns("FINGERPRINT")
      Puppet.stubs(:info)
      Puppet.expects(:info).with { |s| s =~ /FINGERPRINT/ }
      request.generate(key)
    end

    it "should return the generated request" do
      generated = request.generate(key)
      expect(generated).to be_a(OpenSSL::X509::Request)
      expect(generated).to be(request.content)
    end

    it "should use SHA1 to sign the csr when SHA256 isn't available" do
      csr = OpenSSL::X509::Request.new
      OpenSSL::Digest.expects(:const_defined?).with("SHA256").returns(false)
      OpenSSL::Digest.expects(:const_defined?).with("SHA1").returns(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      expect(csr.verify(key.content)).to be_truthy
    end

    it "should raise an error if neither SHA256 nor SHA1 are available" do
      csr = OpenSSL::X509::Request.new
      OpenSSL::Digest.expects(:const_defined?).with("SHA256").returns(false)
      OpenSSL::Digest.expects(:const_defined?).with("SHA1").returns(false)
      expect {
        signer = Puppet::SSL::CertificateSigner.new
      }.to raise_error(Puppet::Error)
    end
  end

  describe "when a CSR is saved" do
    describe "and a CA is available" do
      it "should save the CSR and trigger autosigning" do
        ca = mock 'ca', :autosign
        Puppet::SSL::CertificateAuthority.expects(:instance).returns ca

        csr = Puppet::SSL::CertificateRequest.new("me")
        terminus = mock 'terminus'
        terminus.stubs(:validate)
        Puppet::SSL::CertificateRequest.indirection.expects(:prepare).returns(terminus)
        terminus.expects(:save).with { |request| request.instance == csr && request.key == "me" }

        Puppet::SSL::CertificateRequest.indirection.save(csr)
      end
    end

    describe "and a CA is not available" do
      it "should save the CSR" do
        Puppet::SSL::CertificateAuthority.expects(:instance).returns nil

        csr = Puppet::SSL::CertificateRequest.new("me")
        terminus = mock 'terminus'
        terminus.stubs(:validate)
        Puppet::SSL::CertificateRequest.indirection.expects(:prepare).returns(terminus)
        terminus.expects(:save).with { |request| request.instance == csr && request.key == "me" }

        Puppet::SSL::CertificateRequest.indirection.save(csr)
      end
    end


  end
end
