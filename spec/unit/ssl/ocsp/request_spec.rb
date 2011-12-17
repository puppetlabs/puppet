#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/ssl/ocsp/request'

describe Puppet::SSL::Ocsp::Request do
  include PuppetSpec::Files

  before do
    @class = Puppet::SSL::Ocsp::Request
  end

  it "should be extended with the Indirector module" do
    @class.singleton_class.should be_include(Puppet::Indirector)
  end

  it "should indirect ocsp" do
    @class.indirection.name.should == :ocsp
  end

  it "should only support the text format" do
    @class.supported_formats.should == [:s]
  end

  describe "when converting from a string" do
    it "should create an OCSP request instance" do
      request = stub 'request'
      OpenSSL::OCSP::Request.expects(:new).with("content").returns(request)

      myrequest = stub 'request'
      myrequest.expects(:content=).with(request)

      @class.expects(:new).with("n/a").returns myrequest

      @class.from_s("content")
    end
  end

  describe "when converting to a string" do
    before do
      @ocsp = @class.new("n/a")
    end

    it "should return an empty string when it has no oscp request" do
      @ocsp.to_s.should == ""
    end

    it "should convert the ocsp request to der format" do
      ocsp = mock 'certificate', :to_der => "der"
      @ocsp.content = ocsp
      @ocsp.to_s.should == "der"
    end

    it "should be able to convert multiple instances to a string" do
      ocsp2 = @class.new("foo")
      @ocsp.expects(:to_s).returns "ocsp1"
      ocsp2.expects(:to_s).returns "ocsp2"

      @class.to_multiple_s([@ocsp, ocsp2]).should == "ocsp1\n---\nocsp2"

    end
  end

  describe "when managing instances" do
    before do
      @ocsp = @class.new("myname")
    end

    it "should have a name attribute" do
      @ocsp.name.should == "myname"
    end

    it "should convert its name to a string and downcase it" do
      @class.new(:MyName).name.should == "myname"
    end

    it "should have a content attribute" do
      @ocsp.should respond_to(:content)
    end

    it "should return a nil expiration if there is no actual ocsp request" do
      @ocsp.stubs(:content).returns nil

      @ocsp.expiration.should be_nil
    end
  end

  def make_certs(*crt_names)
    Array(crt_names).map do |name|
      a = Puppet::SSL::Host.new(name) ; a.generate ; a
    end
  end

  describe "#generate" do
    before(:each) do
      Puppet.run_mode.stubs(:master?).returns(true)

      Puppet[:ssldir] = tmpdir("ocsp-ssldir")

      Puppet::SSL::Host.ca_location = :only
      Puppet[:certificate_revocation] = true

      # This is way more intimate than I want to be with the implementation, but
      # there doesn't seem any other way to test this. --daniel 2011-07-18
      Puppet::SSL::CertificateAuthority.stubs(:instance).returns(
          # ...and this actually does the directory creation, etc.
          Puppet::SSL::CertificateAuthority.new
      )

      @ocsp = @class.new("n/a")
    end

    it "should generate an OpenSSL::OCSP::Request" do
      to_check, sign_with = make_certs('to_check', 'sign_with')
      @ocsp.generate(to_check.certificate, sign_with.certificate, sign_with.key, Puppet::SSL::CertificateAuthority.instance)
      @ocsp.content.should be_a(OpenSSL::OCSP::Request)
    end

    it "should generate a request for the certificate to verify" do
      to_check, sign_with = make_certs('to_check', 'sign_with')
      @ocsp.generate(to_check.certificate, sign_with.certificate, sign_with.key, Puppet::SSL::CertificateAuthority.instance)
      @ocsp.content.certid.first.serial.should == to_check.certificate.content.serial
    end

    it "should generate a signed OCSP request" do
      to_check, sign_with = make_certs('to_check', 'sign_with')
      @ocsp.generate(to_check.certificate, sign_with.certificate, sign_with.key, Puppet::SSL::CertificateAuthority.instance)

      ssl_store = OpenSSL::X509::Store.new
      ssl_store.purpose = OpenSSL::X509::PURPOSE_ANY
      ssl_store.add_file(Puppet[:cacert])

      @ocsp.content.verify([sign_with.certificate.content], ssl_store).should be_true
    end
  end

end
