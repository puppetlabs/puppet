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
    described_class.singleton_class.should be_include(Puppet::Indirector)
  end

  it "should indirect certificate_request" do
    described_class.indirection.name.should == :certificate_request
  end

  it "should use any provided name as its name" do
    described_class.new("myname").name.should == "myname"
  end

  it "should only support the text format" do
    described_class.supported_formats.should == [:s]
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
      request.name.should == "myname"
    end

    it "should downcase its name" do
      described_class.new("MyName").name.should == "myname"
    end

    it "should have a content attribute" do
      request.should respond_to(:content)
    end

    it "should be able to read requests from disk" do
      path = "/my/path"
      File.expects(:read).with(path).returns("my request")
      my_req = mock 'request'
      OpenSSL::X509::Request.expects(:new).with("my request").returns(my_req)
      request.read(path).should equal(my_req)
      request.content.should equal(my_req)
    end

    it "should return an empty string when converted to a string with no request" do
      request.to_s.should == ""
    end

    it "should convert the request to pem format when converted to a string" do
      request.generate(key)
      request.to_s.should == request.content.to_pem
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_request = mock 'request'
      real_request.expects(:to_text).returns "requesttext"
      request.content = real_request
      request.to_text.should == "requesttext"
    end
  end

  describe "when generating" do
    it "should use the content of the provided key if the key is a Puppet::SSL::Key instance" do
      request.generate(key)
      request.content.verify(key.content.public_key).should be_true
    end

    it "should set the subject to [CN, name]" do
      request.generate(key)
      # OpenSSL::X509::Name only implements equality as `eql?`
      request.content.subject.should eql OpenSSL::X509::Name.new([['CN', key.name]])
    end

    it "should set the CN to the :ca_name setting when the CSR is for a CA" do
      Puppet[:ca_name] = "mycertname"
      request = described_class.new(Puppet::SSL::CA_NAME).generate(key)
      request.subject.should eql OpenSSL::X509::Name.new([['CN', Puppet[:ca_name]]])
    end

    it "should set the version to 0" do
      request.generate(key)
      request.content.version.should == 0
    end

    it "should set the public key to the provided key's public key" do
      request.generate(key)
      # The openssl bindings do not define equality on keys so we use to_s
      request.content.public_key.to_s.should == key.content.public_key.to_s
    end

    context "without subjectAltName / dns_alt_names" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      ["extreq", "msExtReq"].each do |name|
        it "should not add any #{name} attribute" do
          request.generate(key)
          request.content.attributes.find do |attr|
            attr.oid == name
          end.should_not be
        end

        it "should return no subjectAltNames" do
          request.generate(key)
          request.subject_alt_names.should be_empty
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
          request.content.attributes.find do |attr|
            attr.oid == name
          end.should_not be
        end

        it "should return no subjectAltNames" do
          request.generate(key)
          request.subject_alt_names.should be_empty
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

        extReq.should be
        extReq.value.value.all? do |x|
          x.value.all? do |y|
            y.value[0].value.should == "subjectAltName"
          end
        end
      end

      it "should return the subjectAltName values" do
        request.generate(key, :dns_alt_names => 'one,two')
        request.subject_alt_names.should =~ ["DNS:myname", "DNS:one", "DNS:two"]
      end
    end

    it "should sign the csr with the provided key" do
      request.generate(key)
      request.content.verify(key.content.public_key).should be_true
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
      generated.should be_a(OpenSSL::X509::Request)
      generated.should be(request.content)
    end

    it "should use SHA1 to sign the csr when SHA256 isn't available" do
      csr = OpenSSL::X509::Request.new
      OpenSSL::Digest.expects(:const_defined?).with("SHA256").returns(false)
      OpenSSL::Digest.expects(:const_defined?).with("SHA1").returns(true)
      signer = Puppet::SSL::CertificateSigner.new
      signer.sign(csr, key.content)
      csr.verify(key.content).should be_true
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
