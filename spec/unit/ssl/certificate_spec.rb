#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/certificate'

describe Puppet::SSL::Certificate do
  before do
    @class = Puppet::SSL::Certificate
  end

  after do
    @class.instance_variable_set("@ca_location", nil)
  end

  it "should be extended with the Indirector module" do
    @class.singleton_class.should be_include(Puppet::Indirector)
  end

  it "should indirect certificate" do
    @class.indirection.name.should == :certificate
  end

  it "should only support the text format" do
    @class.supported_formats.should == [:s]
  end

  describe "when converting from a string" do
    it "should create a certificate instance with its name set to the certificate subject and its content set to the extracted certificate" do
      cert = stub 'certificate', :subject => "/CN=Foo.madstop.com"
      OpenSSL::X509::Certificate.expects(:new).with("my certificate").returns(cert)

      mycert = stub 'sslcert'
      mycert.expects(:content=).with(cert)

      @class.expects(:new).with("foo.madstop.com").returns mycert

      @class.from_s("my certificate")
    end

    it "should create multiple certificate instances when asked" do
      cert1 = stub 'cert1'
      @class.expects(:from_s).with("cert1").returns cert1
      cert2 = stub 'cert2'
      @class.expects(:from_s).with("cert2").returns cert2

      @class.from_multiple_s("cert1\n---\ncert2").should == [cert1, cert2]
    end
  end

  describe "when converting to a string" do
    before do
      @certificate = @class.new("myname")
    end

    it "should return an empty string when it has no certificate" do
      @certificate.to_s.should == ""
    end

    it "should convert the certificate to pem format" do
      certificate = mock 'certificate', :to_pem => "pem"
      @certificate.content = certificate
      @certificate.to_s.should == "pem"
    end

    it "should be able to convert multiple instances to a string" do
      cert2 = @class.new("foo")
      @certificate.expects(:to_s).returns "cert1"
      cert2.expects(:to_s).returns "cert2"

      @class.to_multiple_s([@certificate, cert2]).should == "cert1\n---\ncert2"

    end
  end

  describe "when managing instances" do
    before do
      @certificate = @class.new("myname")
    end

    it "should have a name attribute" do
      @certificate.name.should == "myname"
    end

    it "should convert its name to a string and downcase it" do
      @class.new(:MyName).name.should == "myname"
    end

    it "should have a content attribute" do
      @certificate.should respond_to(:content)
    end

    describe "#alternate_names" do
      before do
        Puppet[:certdnsnames] = 'foo:bar:baz'
        @csr            = OpenSSL::X509::Request.new
        @csr.subject    = OpenSSL::X509::Name.new([['CN', 'quux']])
        @csr.public_key = OpenSSL::PKey::RSA.generate(Puppet[:keylength]).public_key
      end

      it "should list all alternate names when the extension is present" do
        cert = Puppet::SSL::CertificateFactory.new('server', @csr, @csr, 14).result

        @certificate = @class.from_s(cert.to_pem)

        @certificate.alternate_names.should =~ ['foo', 'bar', 'baz', 'quux']
      end

      it "should return an empty list of names if the extension is absent" do
        cert = Puppet::SSL::CertificateFactory.new('client', @csr, @csr, 14).result

        @certificate = @class.from_s(cert.to_pem)

        @certificate.alternate_names.should == []
      end
    end

    it "should return a nil expiration if there is no actual certificate" do
      @certificate.stubs(:content).returns nil

      @certificate.expiration.should be_nil
    end

    it "should use the expiration of the certificate as its expiration date" do
      cert = stub 'cert'
      @certificate.stubs(:content).returns cert

      cert.expects(:not_after).returns "sometime"

      @certificate.expiration.should == "sometime"
    end

    it "should be able to read certificates from disk" do
      path = "/my/path"
      File.expects(:read).with(path).returns("my certificate")
      certificate = mock 'certificate'
      OpenSSL::X509::Certificate.expects(:new).with("my certificate").returns(certificate)
      @certificate.read(path).should equal(certificate)
      @certificate.content.should equal(certificate)
    end

    it "should have a :to_text method that it delegates to the actual key" do
      real_certificate = mock 'certificate'
      real_certificate.expects(:to_text).returns "certificatetext"
      @certificate.content = real_certificate
      @certificate.to_text.should == "certificatetext"
    end
  end
end
