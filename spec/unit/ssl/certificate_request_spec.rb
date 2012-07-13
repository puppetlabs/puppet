#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/ssl/certificate_request'
require 'puppet/ssl/key'

describe Puppet::SSL::CertificateRequest do
  before do
    @class = Puppet::SSL::CertificateRequest
  end

  it "should be extended with the Indirector module" do
    @class.singleton_class.should be_include(Puppet::Indirector)
  end

  it "should indirect certificate_request" do
    @class.indirection.name.should == :certificate_request
  end

  it "should use any provided name as its name" do
    @class.new("myname").name.should == "myname"
  end

  it "should only support the text format" do
    @class.supported_formats.should == [:s]
  end

  describe "when converting from a string" do
    it "should create a CSR instance with its name set to the CSR subject and its content set to the extracted CSR" do
      csr = stub 'csr', :subject => "/CN=Foo.madstop.com"
      OpenSSL::X509::Request.expects(:new).with("my csr").returns(csr)

      mycsr = stub 'sslcsr'
      mycsr.expects(:content=).with(csr)

      @class.expects(:new).with("foo.madstop.com").returns mycsr

      @class.from_s("my csr")
    end
  end

  describe "when managing instances" do
    before do
      @request = @class.new("myname")
    end

    it "should have a name attribute" do
      @request.name.should == "myname"
    end

    it "should downcase its name" do
      @class.new("MyName").name.should == "myname"
    end

    it "should have a content attribute" do
      @request.should respond_to(:content)
    end

    it "should be able to read requests from disk" do
      path = "/my/path"
      File.expects(:read).with(path).returns("my request")
      request = mock 'request'
      OpenSSL::X509::Request.expects(:new).with("my request").returns(request)
      @request.read(path).should equal(request)
      @request.content.should equal(request)
    end

    it "should return an empty string when converted to a string with no request" do
      @request.to_s.should == ""
    end

    it "should convert the request to pem format when converted to a string" do
      request = mock 'request', :to_pem => "pem"
      @request.content = request
      @request.to_s.should == "pem"
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_request = mock 'request'
      real_request.expects(:to_text).returns "requesttext"
      @request.content = real_request
      @request.to_text.should == "requesttext"
    end
  end

  describe "when generating" do
    subject  do described_class.new("myname") end
    let :key do Puppet::SSL::Key.new("myname").tap {|key| key.generate } end

    before :each do
      OpenSSL::X509::Request.any_instance.stubs(:verify).returns(true)
    end

    it "should log that it is creating a new certificate request" do
      Puppet::Util::Log.level = :info
      subject.generate(key)
      logs = @logs.map(&:to_s)
      logs.should have_matching_element(/^Creating a new SSL key for/)
      logs.should have_matching_element(/^Creating a new SSL certificate request for/)
      logs.should have_matching_element(/^Certificate Request fingerprint/)
    end

    it "should use the content of the provided key if the key is a Puppet::SSL::Key instance" do
      subject.generate(key).public_key.to_der.should == key.content.public_key.to_der
    end

    it "should set the subject to [CN, name]" do
      subject.generate(key.content).subject.to_s.should == '/CN=myname'
    end

    it "should set the CN to the :ca_name setting when the CSR is for a CA" do
      Puppet[:ca_name] = "mycertname"
      csr = Puppet::SSL::CertificateRequest.new(Puppet::SSL::CA_NAME).generate(key)
      csr.subject.to_s.should == '/CN=mycertname'
    end

    it "should set the version to 0" do
      subject.generate(key).version.should == 0
    end

    it "should set the public key to the provided key's public key" do
      subject.generate(key).public_key.to_der.should == key.content.public_key.to_der
    end

    context "without subjectAltName / dns_alt_names" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      ["extreq", "msExtReq"].each do |name|
        it "should not add any #{name} attribute" do
          OpenSSL::X509::Request.any_instance.expects(:add_attribute).never
          OpenSSL::X509::Request.any_instance.expects(:attributes=).never
          subject.generate(key.content)
        end

        it "should return no subjectAltNames" do
          subject.generate(key.content)
          subject.subject_alt_names.should be_empty
        end
      end
    end

    context "with dns_alt_names" do
      before :each do
        Puppet[:dns_alt_names] = "one, two, three"
      end

      ["extreq", "msExtReq"].each do |name|
        it "should not add any #{name} attribute" do
          OpenSSL::X509::Request.any_instance.expects(:add_attribute).never
          OpenSSL::X509::Request.any_instance.expects(:attributes=).never
          subject.generate(key.content)
        end

        it "should return no subjectAltNames" do
          subject.generate(key.content)
          subject.subject_alt_names.should be_empty
        end
      end
    end

    context "with subjectAltName to generate request" do
      before :each do
        Puppet[:dns_alt_names] = ""
      end

      it "should add an extreq attribute" do
        OpenSSL::X509::Request.any_instance.expects(:add_attribute).with do |arg|
          arg.value.value.all? do |x|
            x.value.all? do |y|
              y.value[0].value == "subjectAltName"
            end
          end
        end

        subject.generate(key.content, :dns_alt_names => 'one, two')
      end

      it "should return the subjectAltName values" do
        subject.generate(key.content, :dns_alt_names => 'one,two')
        subject.subject_alt_names.should =~ ["DNS:myname", "DNS:one", "DNS:two"]
      end
    end

    it "should sign the csr with the provided key and a digest" do
      expect { subject.generate(key) }.to change {
        !!(subject.content and subject.content.verify(key.content)) rescue false
      }.from(false).to(true)
    end

    it "should fail if verification fails" do
      OpenSSL::X509::Request.any_instance.expects(:verify).returns false
      expect { subject.generate(key.content) }.
        to raise_error Puppet::Error, /CSR sign verification failed/
    end

    it "should display the fingerprint" do
      Puppet::Util::Log.level = :info
      subject.generate(key)
      fingerprint = /#{Regexp.escape(subject.fingerprint)}/
      @logs.map(&:to_s).should have_matching_element(fingerprint)
    end

    it "should return the generated request, and set the content to the same object" do
      csr = subject.generate(key)
      csr.should be_an_instance_of OpenSSL::X509::Request
      csr.should equal subject.content
    end
  end

  describe "when a CSR is saved" do
    describe "and a CA is available" do
      it "should save the CSR and trigger autosigning" do
        ca = mock 'ca', :autosign
        Puppet::SSL::CertificateAuthority.expects(:instance).returns ca

        csr = Puppet::SSL::CertificateRequest.new("me")
        terminus = mock 'terminus'
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
        Puppet::SSL::CertificateRequest.indirection.expects(:prepare).returns(terminus)
        terminus.expects(:save).with { |request| request.instance == csr && request.key == "me" }

        Puppet::SSL::CertificateRequest.indirection.save(csr)
      end
    end
  end
end
