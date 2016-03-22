#! /usr/bin/env ruby
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
      @certificate.name.should == "myname"
    end

    it "should convert its name to a string and downcase it" do
      @class.new(:MyName).name.should == "myname"
    end

    it "should have a content attribute" do
      @certificate.should respond_to(:content)
    end

    describe "#subject_alt_names" do
      it "should list all alternate names when the extension is present" do
        certificate = build_cert(:dns_alt_names => 'foo, bar,baz')
        certificate.subject_alt_names.
          should =~ ['DNS:foo', 'DNS:bar', 'DNS:baz', 'DNS:quux']
      end

      it "should return an empty list of names if the extension is absent" do
        certificate = build_cert({})
        certificate.subject_alt_names.should be_empty
      end
    end

    describe "custom extensions" do
      it "returns extensions under the ppRegCertExt" do
        exts = {'pp_uuid' => 'abcdfd'}
        cert = build_cert(:extension_requests => exts)
        expect(cert.custom_extensions).to include('oid' => 'pp_uuid', 'value' => 'abcdfd')
      end

      it "returns extensions under the ppPrivCertExt" do
        exts = {'1.3.6.1.4.1.34380.1.2.1' => 'x509 :('}
        cert = build_cert(:extension_requests => exts)
        expect(cert.custom_extensions).to include('oid' => '1.3.6.1.4.1.34380.1.2.1', 'value' => 'x509 :(')
      end

      it "doesn't return standard extensions" do
        cert = build_cert(:dns_alt_names => 'foo')
        expect(cert.custom_extensions).to be_empty
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

  describe "when checking if the certificate's expiration is approaching" do
    before do
      @days = 24*60*60
      @certificate = @class.new("myname")
      @certificate.stubs(:expiration).returns(Time.now.utc() + 30*@days)
    end

    it "should be true if the expiration is within the given interval from now" do
      @certificate.near_expiration?(31*@days).should be_true
    end

    it "should be false if there is no expiration" do
      @certificate.stubs(:expiration).returns(nil)
      @certificate.near_expiration?.should be_false
    end

    it "should default to using the `certificate_expire_warning` setting as the interval" do
      Puppet[:certificate_expire_warning] = 31*@days
      @certificate.near_expiration?.should be_true
      Puppet[:certificate_expire_warning] = 29*@days
      @certificate.near_expiration?.should be_false
    end
  end
end
