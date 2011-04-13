#!/usr/bin/env rspec
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require 'spec_helper'

require 'puppet/file_serving/indirection_hooks'

describe Puppet::FileServing::IndirectionHooks do
  before do
    @object = Object.new
    @object.extend(Puppet::FileServing::IndirectionHooks)

    @request = stub 'request', :key => "mymod/myfile", :options => {:node => "whatever"}, :server => nil, :protocol => nil
  end

  describe "when being used to select termini" do
    it "should return :file if the request key is fully qualified" do
      @request.expects(:key).returns "#{File::SEPARATOR}foo"
      @object.select_terminus(@request).should == :file
    end

    it "should return :file if the URI protocol is set to 'file'" do
      @request.expects(:protocol).returns "file"
      @object.select_terminus(@request).should == :file
    end

    it "should fail when a protocol other than :puppet or :file is used" do
      @request.stubs(:protocol).returns "http"
      proc { @object.select_terminus(@request) }.should raise_error(ArgumentError)
    end

    describe "and the protocol is 'puppet'" do
      before do
        @request.stubs(:protocol).returns "puppet"
      end

      it "should choose :rest when a server is specified" do
        @request.stubs(:protocol).returns "puppet"
        @request.expects(:server).returns "foo"
        @object.select_terminus(@request).should == :rest
      end

      # This is so a given file location works when bootstrapping with no server.
      it "should choose :rest when the Settings name isn't 'puppet'" do
        @request.stubs(:protocol).returns "puppet"
        @request.stubs(:server).returns "foo"
        Puppet.settings.stubs(:value).with(:name).returns "foo"
        @object.select_terminus(@request).should == :rest
      end

      it "should choose :file_server when the settings name is 'puppet' and no server is specified" do
        modules = mock 'modules'

        @request.expects(:protocol).returns "puppet"
        @request.expects(:server).returns nil
        Puppet.settings.expects(:value).with(:name).returns "puppet"
        @object.select_terminus(@request).should == :file_server
      end
    end
  end
end
