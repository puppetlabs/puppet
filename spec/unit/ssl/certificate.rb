#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/ssl/certificate'

describe Puppet::SSL::Certificate do
    before do
        @class = Puppet::SSL::Certificate
    end

    it "should be extended with the Indirector module" do
        @class.metaclass.should be_include(Puppet::Indirector)
    end

    it "should indirect certificate" do
        @class.indirection.name.should == :certificate
    end

    describe "when managing instances" do
        before do
            @cert = @class.new("myname")
        end

        it "should have a name attribute" do
            @cert.name.should == "myname"
        end

        it "should have a content attribute" do
            @cert.should respond_to(:content)
        end
    end

    describe "when generating the certificate" do
        it "should fail because certificates must be created by a certificate authority" do
            @instance = @class.new("test")
            lambda { @instance.generate }.should raise_error(Puppet::DevError)
        end
    end
end
