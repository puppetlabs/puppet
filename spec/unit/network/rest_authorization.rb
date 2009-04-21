#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/network/rest_authorization'

class RestAuthorized
    include Puppet::Network::RestAuthorization
end


describe Puppet::Network::RestAuthorization do
    before :each do
        @auth = RestAuthorized.new
        @authconig = stub 'authconfig'
        @auth.stubs(:authconfig).returns(@authconfig)

        @request = stub_everything 'request'
        @request.stubs(:method).returns(:find)
        @request.stubs(:node).returns("node")
    end

    describe "when testing request authorization" do
        describe "when the client is not authenticated" do
            before :each do
                @request.stubs(:authenticated?).returns(false)
            end

            [ :certificate, :certificate_request].each do |indirection|
                it "should allow #{indirection}" do
                    @request.stubs(:indirection_name).returns(indirection)
                    @auth.authorized?(@request).should be_true
                end
            end

            [ :facts, :file_metadata, :file_content, :catalog, :report, :checksum, :runner ].each do |indirection|
                it "should not allow #{indirection}" do
                    @request.stubs(:indirection_name).returns(indirection)
                    @auth.authorized?(@request).should be_false
                end
            end
        end

        describe "when the client is authenticated" do
            before :each do
                @request.stubs(:authenticated?).returns(true)
            end

            it "should delegate to the current rest authconfig" do
                @authconfig.expects(:allowed?).with(@request)

                @auth.authorized?(@request)
            end
        end
    end
end