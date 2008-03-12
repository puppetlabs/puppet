#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate_authority'

describe Puppet::SSL::CertificateAuthority do
    describe "when initializing" do
        it "should always set its name to the value of :certname" do
            Puppet.settings.expects(:value).with(:certname).returns "whatever"

            Puppet::SSL::CertificateAuthority.any_instance.stubs(:setup_ca)

            Puppet::SSL::CertificateAuthority.new.name.should == "whatever"
        end

        describe "a new certificate authority" do
            it "should create and store a password at :capass, a key encrypted with the password at :cakey, and a self-signed cert at :cacert"
        end

        describe "an existing certificate authority" do
            it "should read and decrypt the key at :cakey using the password at :capass and it should read the cert at :cacert"

            it "should read the cert stored at :cacert"
        end
    end
end
