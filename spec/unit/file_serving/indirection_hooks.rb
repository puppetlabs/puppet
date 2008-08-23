#!/usr/bin/env ruby
#
#  Created by Luke Kanies on 2007-10-18.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'

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

            it "should not choose :rest when the settings name is 'puppet' and no server is specified" do
                modules = mock 'modules'

                @object.stubs(:terminus).with(:modules).returns(modules)
                modules.stubs(:find_module).with("mymod", @request.options[:node]).returns nil

                @request.expects(:protocol).returns "puppet"
                @request.expects(:server).returns nil
                Puppet.settings.expects(:value).with(:name).returns "puppet"
                @object.select_terminus(@request).should_not == :rest
            end
        end

        describe "and the terminus is not :rest or :file" do
            before do
                @request.stubs(:protocol).returns nil
            end

            it "should choose :modules if the mount name is 'modules'" do
                @request.stubs(:key).returns "modules/mymod/file"
                @object.select_terminus(@request).should == :modules
            end

            it "should choose :modules and provide a deprecation notice if a module exists with the mount name" do
                modules = mock 'modules'

                @object.expects(:terminus).with(:modules).returns(modules)
                modules.expects(:find_module).with("mymod", @request.options[:node]).returns(:thing)

                Puppet.expects(:warning)

                @request.stubs(:key).returns "mymod/file"
                @object.select_terminus(@request).should == :modules
            end

            it "should choose :file_server if the mount name is not 'modules' nor matches a module name" do
                modules = mock 'modules'
                @object.stubs(:terminus).with(:modules).returns(modules)
                modules.stubs(:find_module).returns(nil)

                @request.stubs(:key).returns "puppetmounts://host/notmodules/file"

                @object.select_terminus(@request).should == :file_server
            end
        end

        describe "when looking for a module whose name matches the mount name" do
            before do
                @modules = mock 'modules'
                @object.stubs(:terminus).with(:modules).returns(@modules)

                @request.stubs(:key).returns "mymod/file"
            end

            it "should use the modules terminus to look up the module" do
                @modules.expects(:find_module).with("mymod", @request.options[:node])
                @object.select_terminus @request
            end

            it "should pass the node name to the modules terminus" do
                @modules.expects(:find_module).with("mymod", @request.options[:node])
                @object.select_terminus @request
            end

            it "should log a deprecation warning if a module is found" do
                @modules.expects(:find_module).with("mymod", @request.options[:node]).returns(:something)
                Puppet.expects(:warning)
                @object.select_terminus @request
            end
        end
    end
end
