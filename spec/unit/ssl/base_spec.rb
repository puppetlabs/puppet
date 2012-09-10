#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/ssl/certificate'

class TestCertificate < Puppet::SSL::Base
    wraps(Puppet::SSL::Certificate)
end

describe Puppet::SSL::Certificate do
  before :each do
    @base = TestCertificate.new("name")
    @class = TestCertificate
  end

  describe "when fingerprinting content" do
    before :each do
      @cert = stub 'cert', :to_der => "DER"
      @base.stubs(:content).returns(@cert)
      OpenSSL::Digest.stubs(:constants).returns ["MD5", "SHA1", "SHA256", "SHA512", "DIGEST"]
      @digest = stub_everything
      OpenSSL::Digest.stubs(:const_get).returns @digest
    end

    it "should digest the certificate DER value and return a ':' seperated nibblet string" do
      @cert.expects(:to_der).returns("DER")
      @digest.expects(:hexdigest).with("DER").returns "digest"

      @base.fingerprint.should == "DI:GE:ST"
    end

    it "should raise an error if the digest algorithm is not defined" do
      OpenSSL::Digest.expects(:constants).returns []

      lambda { @base.fingerprint }.should raise_error
    end

    it "should use the given digest algorithm" do
      OpenSSL::Digest.stubs(:const_get).with("DIGEST").returns @digest
      @digest.expects(:hexdigest).with("DER").returns "digest"

      @base.fingerprint(:digest).should == "DI:GE:ST"
    end
  end

  describe "when creating new instances" do
    it "should fail if given an object that is not an instance of the wrapped class" do
      obj = stub 'obj', :is_a? => false
      lambda { @class.from_instance(obj) }.should raise_error(ArgumentError)
    end

    it "should fail if a name is not supplied and can't be determined from the object" do
      obj = stub 'obj', :is_a? => true
      lambda { @class.from_instance(obj) }.should raise_error(ArgumentError)
    end

    it "should determine the name from the object if it has a subject" do
      obj = stub 'obj', :is_a? => true, :subject => '/CN=foo'

      inst = stub 'base'
      inst.expects(:content=).with(obj)

      @class.expects(:new).with('foo').returns inst
      @class.expects(:name_from_subject).with('/CN=foo').returns('foo')

      @class.from_instance(obj).should == inst
    end
  end

  describe "when determining a name from a certificate subject" do
    it "should convert it to a string" do
      subject = stub 'sub'
      subject.expects(:to_s).returns('foo')

      @class.name_from_subject(subject).should == 'foo'
    end

    it "should strip the prefix" do
      subject = '/CN=foo'
      @class.name_from_subject(subject).should == 'foo'
    end
  end
end
