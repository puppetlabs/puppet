#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/server'
require 'puppet/indirector'
require 'puppet/indirector/rest'

# a fake class that will be indirected via REST
class Puppet::TestIndirectedFoo
    extend Puppet::Indirector
    indirects :test_indirected_foo, :terminus_setting => :test_indirected_foo_terminus

    attr_reader :value
    attr_accessor :name

    def initialize(value = 0)
        @value = value
    end

    def self.from_yaml(yaml)
        YAML.load(yaml)
    end

    def name
        "bob"
    end
end

# empty Terminus class -- this would normally have to be in a directory findable by the autoloader, but we short-circuit that below
class Puppet::TestIndirectedFoo::Rest < Puppet::Indirector::REST
end


describe Puppet::Indirector::REST do
    before do
        # Get a safe temporary file
        @tmpfile = Tempfile.new("webrick_integration_testing")
        @dir = @tmpfile.path + "_dir"

        Puppet.settings[:confdir] = @dir
        Puppet.settings[:vardir] = @dir
        Puppet.settings[:server] = "127.0.0.1"
        Puppet.settings[:masterport] = "34343"

        Puppet::SSL::Host.ca_location = :local

        Puppet::TestIndirectedFoo.terminus_class = :rest
    end

    after do
        Puppet::Network::HttpPool.expire
        Puppet::SSL::Host.ca_location = :none
        Puppet.settings.clear
    end

    describe "when using webrick" do
        before :each do
            Puppet::Util::Cacher.expire

            Puppet[:servertype] = 'webrick'
            Puppet[:server] = '127.0.0.1'
            Puppet[:certname] = '127.0.0.1'

            ca = Puppet::SSL::CertificateAuthority.new
            ca.generate(Puppet[:certname]) unless Puppet::SSL::Certificate.find(Puppet[:certname])

            @params = { :port => 34343, :handlers => [ :test_indirected_foo ], :xmlrpc_handlers => [ :status ] }
            @server = Puppet::Network::Server.new(@params)
            @server.listen

            # LAK:NOTE We need to have a fake model here so that our indirected methods get
            # passed through REST; otherwise we'd be stubbing 'find', which would cause an immediate
            # return.
            @mock_model = stub('faked model', :name => "foo")
            Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)

            # do not trigger the authorization layer
            Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:check_authorization).returns(true)
        end

        describe "when finding a model instance over REST" do
            describe "when a matching model instance can be found" do
                before :each do
                    @model_instance = Puppet::TestIndirectedFoo.new(23)
                    @mock_model.stubs(:find).returns @model_instance
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should_not raise_error
                end

                it 'should return an instance of the model class' do
                    Puppet::TestIndirectedFoo.find('bar').class.should == Puppet::TestIndirectedFoo
                end

                it "should pass options all the way through" do
                    @mock_model.expects(:find).with { |key, args| args[:one] == "two" and args[:three] == "four" }.returns @model_instance
                    Puppet::TestIndirectedFoo.find('bar', :one => "two", :three => "four")
                end

                it 'should return the instance of the model class associated with the provided lookup key' do
                    Puppet::TestIndirectedFoo.find('bar').value.should == @model_instance.value
                end

                it 'should set an expiration on model instance' do
                    Puppet::TestIndirectedFoo.find('bar').expiration.should_not be_nil
                end

                it "should use a supported format" do
                    Puppet::TestIndirectedFoo.expects(:supported_formats).returns ["marshal"]
                    text = Marshal.dump(@model_instance)
                    @model_instance.expects(:render).with(Puppet::Network::FormatHandler.format("marshal")).returns text
                    Puppet::TestIndirectedFoo.find('bar')
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model = stub('faked model', :name => "foo", :find => nil)
                    Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)
                end

                it "should return nil" do
                    Puppet::TestIndirectedFoo.find('bar').should be_nil
                end
            end

            describe "when an exception is encountered in looking up a model instance" do
                before :each do
                    @mock_model = stub('faked model', :name => "foo")
                    @mock_model.stubs(:find).raises(RuntimeError)
                    Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when searching for model instances over REST" do
            describe "when matching model instances can be found" do
                before :each do
                    @model_instances = [ Puppet::TestIndirectedFoo.new(23), Puppet::TestIndirectedFoo.new(24) ]
                    @mock_model.stubs(:search).returns @model_instances

                    # Force yaml, because otherwise our mocks can't work correctly
                    Puppet::TestIndirectedFoo.stubs(:supported_formats).returns %w{yaml}

                    @mock_model.stubs(:render_multiple).returns @model_instances.to_yaml
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.search('bar') }.should_not raise_error
                end

                it 'should return all matching results' do
                    Puppet::TestIndirectedFoo.search('bar').length.should == @model_instances.length
                end

                it "should pass options all the way through" do
                    @mock_model.expects(:search).with { |key, args| args[:one] == "two" and args[:three] == "four" }.returns @model_instances
                    Puppet::TestIndirectedFoo.search("foo", :one => "two", :three => "four")
                end

                it 'should return model instances' do
                    Puppet::TestIndirectedFoo.search('bar').each do |result|
                        result.class.should == Puppet::TestIndirectedFoo
                    end
                end

                it 'should return the instance of the model class associated with the provided lookup key' do
                    Puppet::TestIndirectedFoo.search('bar').collect { |i| i.value }.should == @model_instances.collect { |i| i.value }
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model = stub('faked model', :name => "foo", :find => nil)
                    Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)
                end

                it "should return nil" do
                    Puppet::TestIndirectedFoo.find('bar').should be_nil
                end
            end

            describe "when an exception is encountered in looking up a model instance" do
                before :each do
                    @mock_model = stub('faked model')
                    @mock_model.stubs(:find).raises(RuntimeError)
                    Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when destroying a model instance over REST" do
            describe "when a matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:destroy).returns true
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should_not raise_error
                end

                it 'should return success' do
                    Puppet::TestIndirectedFoo.destroy('bar').should == true
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:destroy).returns false
                end

                it "should return failure" do
                    Puppet::TestIndirectedFoo.destroy('bar').should == false
                end
            end

            describe "when an exception is encountered in destroying a model instance" do
                before :each do
                    @mock_model.stubs(:destroy).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when saving a model instance over REST" do
            before :each do
                @instance = Puppet::TestIndirectedFoo.new(42)
                @mock_model.stubs(:save_object).returns @instance
                @mock_model.stubs(:convert_from).returns @instance
                Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).returns(@instance)
            end

            describe "when a successful save can be performed" do
                before :each do
                end

                it "should not fail" do
                    lambda { @instance.save }.should_not raise_error
                end

                it 'should return an instance of the model class' do
                    @instance.save.class.should == Puppet::TestIndirectedFoo
                end

                it 'should return a matching instance of the model class' do
                    @instance.save.value.should == @instance.value
                end
            end

            describe "when a save cannot be completed" do
                before :each do
                    Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).returns(false)
                end

                it "should return failure" do
                    @instance.save.should == false
                end
            end

            describe "when an exception is encountered in performing a save" do
                before :each do
                    Puppet::Network::HTTP::WEBrickREST.any_instance.stubs(:save_object).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { @instance.save }.should raise_error(Net::HTTPError)
                end
            end
        end

        after :each do
            @server.unlisten
        end
    end

    describe "when using mongrel" do
        confine "Mongrel is not available" => Puppet.features.mongrel?

        before :each do
            Puppet[:servertype] = 'mongrel'
            @params = { :port => 34343, :handlers => [ :test_indirected_foo ] }

            # Make sure we never get a cert, since mongrel can't speak ssl
            Puppet::SSL::Certificate.stubs(:find).returns nil

            # We stub ssl to be off, since mongrel can't speak ssl
            Net::HTTP.any_instance.stubs(:use_ssl?).returns false

            @server = Puppet::Network::Server.new(@params)
            @server.listen

            # LAK:NOTE We need to have a fake model here so that our indirected methods get
            # passed through REST; otherwise we'd be stubbing 'find', which would cause an immediate
            # return.
            @mock_model = stub('faked model', :name => "foo")
            Puppet::Indirector::Request.any_instance.stubs(:model).returns(@mock_model)

            # do not trigger the authorization layer
            Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:check_authorization).returns(true)
        end

        after do
            @server.unlisten
        end

        describe "when finding a model instance over REST" do
            describe "when a matching model instance can be found" do
                before :each do
                    @model_instance = Puppet::TestIndirectedFoo.new(23)
                    @mock_model.stubs(:find).returns @model_instance
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should_not raise_error
                end

                it 'should return an instance of the model class' do
                    Puppet::TestIndirectedFoo.find('bar').class.should == Puppet::TestIndirectedFoo
                end

                it "should pass options all the way through" do
                    @mock_model.expects(:find).with { |key, args| args[:one] == "two" and args[:three] == "four" }.returns @model_instance
                    Puppet::TestIndirectedFoo.find('bar', :one => "two", :three => "four")
                end

                it 'should return the instance of the model class associated with the provided lookup key' do
                    Puppet::TestIndirectedFoo.find('bar').value.should == @model_instance.value
                end

                it 'should set an expiration on model instance' do
                    Puppet::TestIndirectedFoo.find('bar').expiration.should_not be_nil
                end

                it "should use a supported format" do
                    Puppet::TestIndirectedFoo.expects(:supported_formats).returns ["marshal"]
                    format = stub 'format'
                    text = Marshal.dump(@model_instance)
                    @model_instance.expects(:render).with(Puppet::Network::FormatHandler.format("marshal")).returns text
                    Puppet::TestIndirectedFoo.find('bar')
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:find).returns nil
                end

                it "should return nil" do
                    Puppet::TestIndirectedFoo.find('bar').should be_nil
                end
            end

            describe "when an exception is encountered in looking up a model instance" do
                before :each do
                    @mock_model.stubs(:find).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when searching for model instances over REST" do
            describe "when matching model instances can be found" do
                before :each do
                    @model_instances = [ Puppet::TestIndirectedFoo.new(23), Puppet::TestIndirectedFoo.new(24) ]

                    # Force yaml, because otherwise our mocks can't work correctly
                    Puppet::TestIndirectedFoo.stubs(:supported_formats).returns %w{yaml}

                    @mock_model.stubs(:search).returns @model_instances
                    @mock_model.stubs(:render_multiple).returns @model_instances.to_yaml
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.search('bar') }.should_not raise_error
                end

                it 'should return all matching results' do
                    Puppet::TestIndirectedFoo.search('bar').length.should == @model_instances.length
                end

                it "should pass options all the way through" do
                    @mock_model.expects(:search).with { |key, args| args[:one] == "two" and args[:three] == "four" }.returns @model_instances
                    Puppet::TestIndirectedFoo.search('bar', :one => "two", :three => "four")
                end

                it 'should return model instances' do
                    Puppet::TestIndirectedFoo.search('bar').each do |result|
                        result.class.should == Puppet::TestIndirectedFoo
                    end
                end

                it 'should return the instance of the model class associated with the provided lookup key' do
                    Puppet::TestIndirectedFoo.search('bar').collect { |i| i.value }.should == @model_instances.collect { |i| i.value }
                end

                it 'should set an expiration on model instances' do
                    Puppet::TestIndirectedFoo.search('bar').each do |result|
                        result.expiration.should_not be_nil
                    end
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:search).returns nil
                    @mock_model.stubs(:render_multiple).returns nil.to_yaml
                end

                it "should return nil" do
                    Puppet::TestIndirectedFoo.search('bar').should == []
                end
            end

            describe "when an exception is encountered in looking up a model instance" do
                before :each do
                    @mock_model.stubs(:find).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.find('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when destroying a model instance over REST" do
            describe "when a matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:destroy).returns true
                end

                it "should not fail" do
                    lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should_not raise_error
                end

                it 'should return success' do
                    Puppet::TestIndirectedFoo.destroy('bar').should == true
                end
            end

            describe "when no matching model instance can be found" do
                before :each do
                    @mock_model.stubs(:destroy).returns false
                end

                it "should return failure" do
                    Puppet::TestIndirectedFoo.destroy('bar').should == false
                end
            end

            describe "when an exception is encountered in destroying a model instance" do
                before :each do
                    @mock_model.stubs(:destroy).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { Puppet::TestIndirectedFoo.destroy('bar') }.should raise_error(Net::HTTPError)
                end
            end
        end

        describe "when saving a model instance over REST" do
            before :each do
                @instance = Puppet::TestIndirectedFoo.new(42)
                @mock_model.stubs(:convert_from).returns @instance

                # LAK:NOTE This stub is necessary to prevent the REST call from calling
                # REST.save again, thus producing painful infinite recursion.
                Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).returns(@instance)
            end

            describe "when a successful save can be performed" do
                before :each do
                end

                it "should not fail" do
                    lambda { @instance.save }.should_not raise_error
                end

                it 'should return an instance of the model class' do
                    @instance.save.class.should == Puppet::TestIndirectedFoo
                end

                it 'should return a matching instance of the model class' do
                    @instance.save.value.should == @instance.value
                end
            end

            describe "when a save cannot be completed" do
                before :each do
                    Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).returns(false)
                end

                it "should return failure" do
                    @instance.save.should == false
                end
            end

            describe "when an exception is encountered in performing a save" do
                before :each do
                    Puppet::Network::HTTP::MongrelREST.any_instance.stubs(:save_object).raises(RuntimeError)
                end

                it "should raise an exception" do
                    lambda { @instance.save }.should raise_error(Net::HTTPError)
                end
            end
        end
    end
end
