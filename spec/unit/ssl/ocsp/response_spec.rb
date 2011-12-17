#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/ssl/ocsp/response'
require 'puppet/ssl/ocsp/request'

describe Puppet::SSL::Ocsp::Response do
  include PuppetSpec::Files

  before do
    @class = Puppet::SSL::Ocsp::Response
  end

  it "should only support the yaml format" do
    @class.supported_formats.should == [:yaml]
  end

  describe "when converting from YAML" do
    it "should create an OCSP response instance" do
      response = stub 'response'
      OpenSSL::OCSP::Response.expects(:new).returns(response)

      myresponse = stub 'response'
      myresponse.expects(:content=).with(response)

      @class.expects(:new).with("fake").returns myresponse

      @class.from_yaml("content")
    end
  end

  describe "when converting to YAML" do
    before do
      @ocsp = @class.new("n/a")
    end

    it "should return an empty string when it has no oscp response" do
      @ocsp.to_yaml.should == YAML.dump("")
    end

    it "should convert the ocsp response to der format and then YAML" do
      ocsp = mock 'ocsp', :to_der => "der"
      @ocsp.content = ocsp
      @ocsp.to_yaml.should == YAML.dump(Base64.encode64("der"))
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
  end

  describe "#verify" do
    before(:each) do
      @ocsp = @class.new("n/a")
      @request = Puppet::SSL::Ocsp::Request.new("n/a")
      @request.content = stub 'request'
      @basic = stub 'basic'
    end

    it "should raise an error if verification failed" do
      @ocsp.content = stub 'response', :status => 2
      lambda{ @ocsp.verify(@request) }.should raise_error
    end

    it "should raise an error if response don't contain a basic response" do
      @ocsp.content = stub 'response', :basic => nil
      lambda{ @ocsp.verify(@request) }.should raise_error
    end

    it "should raise an error if nonce don't match" do
      @request.content.expects(:check_nonce).returns(0)
      @ocsp.content = stub 'response', :basic => @basic, :status => 0
      lambda { @ocsp.verify(@request) }.should raise_error
    end

    it "should raise an error if there is no results" do
      @request.content.stubs(:check_nonce).returns(0)
      @ocsp.content = stub 'response', :basic => @basic, :status => 0
      @basic.stubs(:status).returns([])
      lambda { @ocsp.verify(@request) }.should raise_error
    end

    describe "when returning the status" do
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
      end

      def make_certs(*crt_names)
        Array(crt_names).map do |name|
          a = Puppet::SSL::Host.new(name) ; a.generate ; a
        end
      end


      it "should return an array of status" do
        Time.stubs(:now).returns(Time.utc(2011,11,19,18,05,17))
        cert = make_certs('check')
        @request.content.stubs(:check_nonce).returns(1)
        @ocsp.content = stub 'response', :basic => @basic, :status => 0
        @basic.stubs(:status).returns([[OpenSSL::OCSP::CertificateId.new(cert.first.certificate.content, Puppet::SSL::CertificateAuthority.instance.host.certificate.content), OpenSSL::OCSP::V_CERTSTATUS_GOOD, nil, nil, Time.now, Time.now]])

        @ocsp.verify(@request).should == [{ :serial => 2, :valid=>true, :revocation_reason=>nil, :revoked_at => nil, :ttl => Time.now}]
      end
    end
  end
end
