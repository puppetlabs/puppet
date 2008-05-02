#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/server'

describe Puppet::Network::Server, "when initializing" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)

        Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
        Puppet::Network::Handler.stubs(:handler).returns mock('xmlrpc_handler')
    end

    it "should allow specifying a listening address" do
        Puppet.stubs(:[]).with(:masterport).returns('')
        @server = Puppet::Network::Server.new(:address => "127.0.0.1")
        @server.address.should == "127.0.0.1"
    end

    it "should allow specifying a listening port" do
        Puppet.stubs(:[]).with(:bindaddress).returns('')
        @server = Puppet::Network::Server.new(:port => 31337)
        @server.port.should == 31337
    end

    it "should use the Puppet configurator to find a default listening address" do
        Puppet.stubs(:[]).with(:masterport).returns('')
        Puppet.expects(:[]).with(:bindaddress).returns("10.0.0.1")
        @server = Puppet::Network::Server.new
        @server.address.should == "10.0.0.1"
    end

    it "should use the Puppet configurator to find a default listening port" do
        Puppet.stubs(:[]).with(:bindaddress).returns('')
        Puppet.expects(:[]).with(:masterport).returns(6667)
        @server = Puppet::Network::Server.new
        @server.port.should == 6667
    end

    it "should fail to initialize if no listening address can be found" do
        Puppet.stubs(:[]).with(:masterport).returns(6667)
        Puppet.stubs(:[]).with(:bindaddress).returns(nil)
        lambda { Puppet::Network::Server.new }.should raise_error(ArgumentError)
    end

    it "should fail to initialize if no listening port can be found" do
        Puppet.stubs(:[]).with(:bindaddress).returns("127.0.0.1")
        Puppet.stubs(:[]).with(:masterport).returns(nil)
        lambda { Puppet::Network::Server.new }.should raise_error(ArgumentError)        
    end

    it "should use the Puppet configurator to determine which HTTP server will be used to provide access to clients" do
        Puppet.expects(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @server.server_type.should == :suparserver
    end

    it "should fail to initialize if there is no HTTP server known to the Puppet configurator" do
        Puppet.expects(:[]).with(:servertype).returns(nil)
        lambda { Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337) }.should raise_error
    end

    it "should ask the Puppet::Network::HTTP class to fetch the proper HTTP server class" do
        Puppet::Network::HTTP.expects(:server_class_by_type).with(:suparserver).returns(@mock_http_server_class)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
    end

    it "should fail if the HTTP server class is unknown" do
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(nil)
        lambda { Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337) }.should raise_error(ArgumentError)
    end

    it "should allow registering REST handlers" do
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337, :handlers => [ :foo, :bar, :baz])
        lambda { @server.unregister(:foo, :bar, :baz) }.should_not raise_error
    end

    it "should allow registering XMLRPC handlers" do
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337, :xmlrpc_handlers => [ :foo, :bar, :baz])
        lambda { @server.unregister_xmlrpc(:foo, :bar, :baz) }.should_not raise_error
    end

    it "should not be listening after initialization" do
        Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337).should_not be_listening
    end
end

describe Puppet::Network::Server do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
    end

    describe "when managing indirection registrations" do
        before do
            Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
        end

        it "should allow registering an indirection for client access by specifying its indirection name" do
            lambda { @server.register(:foo) }.should_not raise_error
        end

        it "should require that the indirection be valid" do
            Puppet::Indirector::Indirection.expects(:model).with(:foo).returns nil
            lambda { @server.register(:foo) }.should raise_error(ArgumentError)
        end

        it "should require at least one indirection name when registering indirections for client access" do
            lambda { @server.register }.should raise_error(ArgumentError)
        end

        it "should allow for numerous indirections to be registered at once for client access" do
            lambda { @server.register(:foo, :bar, :baz) }.should_not raise_error
        end

        it "should allow the use of indirection names to specify which indirections are to be no longer accessible to clients" do
            @server.register(:foo)
            lambda { @server.unregister(:foo) }.should_not raise_error    
        end

        it "should leave other indirections accessible to clients when turning off indirections" do
            @server.register(:foo, :bar)
            @server.unregister(:foo)
            lambda { @server.unregister(:bar)}.should_not raise_error
        end

        it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
            @server.register(:foo, :bar)
            lambda { @server.unregister(:foo, :bar) }.should_not raise_error
        end

        it "should not turn off any indirections if given unknown indirection names to turn off" do
            @server.register(:foo, :bar)
            lambda { @server.unregister(:foo, :bar, :baz) }.should raise_error(ArgumentError)
            lambda { @server.unregister(:foo, :bar) }.should_not raise_error
        end

        it "should not allow turning off unknown indirection names" do
            @server.register(:foo, :bar)
            lambda { @server.unregister(:baz) }.should raise_error(ArgumentError)
        end

        it "should disable client access immediately when turning off indirections" do
            @server.register(:foo, :bar)
            @server.unregister(:foo)    
            lambda { @server.unregister(:foo) }.should raise_error(ArgumentError)
        end

        it "should allow turning off all indirections at once" do
            @server.register(:foo, :bar)
            @server.unregister
            [ :foo, :bar, :baz].each do |indirection|
                lambda { @server.unregister(indirection) }.should raise_error(ArgumentError)
            end
        end
    end

    it "should provide a means of determining whether it is listening" do
        @server.should respond_to(:listening?)
    end

    it "should provide a means of determining which HTTP server will be used to provide access to clients" do
        @server.server_type.should == :suparserver
    end

    it "should provide a means of determining which protocols are in use" do
        @server.should respond_to(:protocols)
    end

    it "should set the protocols to :rest and :xmlrpc" do
        @server.protocols.should == [ :rest, :xmlrpc ]
    end

    it "should provide a means of determining the listening address" do
        @server.address.should == "127.0.0.1"
    end

    it "should provide a means of determining the listening port" do
        @server.port.should == 31337
    end

    it "should allow for multiple configurations, each handling different indirections" do
        Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')

        @server2 = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @server.register(:foo, :bar)
        @server2.register(:foo, :xyzzy)
        @server.unregister(:foo, :bar)
        @server2.unregister(:foo, :xyzzy)
        lambda { @server.unregister(:xyzzy) }.should raise_error(ArgumentError)
        lambda { @server2.unregister(:bar) }.should raise_error(ArgumentError)
    end  

    describe "when managing xmlrpc registrations" do
        before do
            Puppet::Network::Handler.stubs(:handler).returns mock('xmlrpc_handler')
        end

        it "should allow registering an xmlrpc handler by specifying its namespace" do
            lambda { @server.register_xmlrpc(:foo) }.should_not raise_error
        end

        it "should require that the xmlrpc namespace be valid" do
            Puppet::Network::Handler.stubs(:handler).returns nil

            lambda { @server.register_xmlrpc(:foo) }.should raise_error(ArgumentError)
        end

        it "should require at least one namespace" do
            lambda { @server.register_xmlrpc() }.should raise_error(ArgumentError)
        end

        it "should allow multiple namespaces to be registered at once" do
            lambda { @server.register_xmlrpc(:foo, :bar) }.should_not raise_error
        end

        it "should allow the use of namespaces to specify which are no longer accessible to clients" do
            @server.register_xmlrpc(:foo, :bar)
        end

        it "should leave other namespaces accessible to clients when turning off xmlrpc namespaces" do
            @server.register_xmlrpc(:foo, :bar)
            @server.unregister_xmlrpc(:foo)
            lambda { @server.unregister_xmlrpc(:bar)}.should_not raise_error
        end

        it "should allow specifying numerous namespaces which are to be no longer accessible to clients" do
            @server.register_xmlrpc(:foo, :bar)
            lambda { @server.unregister_xmlrpc(:foo, :bar) }.should_not raise_error
        end

        it "should not turn off any indirections if given unknown namespaces to turn off" do
            @server.register_xmlrpc(:foo, :bar)
            lambda { @server.unregister_xmlrpc(:foo, :bar, :baz) }.should raise_error(ArgumentError)
            lambda { @server.unregister_xmlrpc(:foo, :bar) }.should_not raise_error
        end

        it "should not allow turning off unknown namespaces" do
            @server.register_xmlrpc(:foo, :bar)
            lambda { @server.unregister_xmlrpc(:baz) }.should raise_error(ArgumentError)
        end

        it "should disable client access immediately when turning off namespaces" do
            @server.register_xmlrpc(:foo, :bar)
            @server.unregister_xmlrpc(:foo)    
            lambda { @server.unregister_xmlrpc(:foo) }.should raise_error(ArgumentError)
        end

        it "should allow turning off all namespaces at once" do
            @server.register_xmlrpc(:foo, :bar)
            @server.unregister_xmlrpc
            [ :foo, :bar, :baz].each do |indirection|
                lambda { @server.unregister_xmlrpc(indirection) }.should raise_error(ArgumentError)
            end
        end
    end
end

describe Puppet::Network::Server, "when listening is off" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @mock_http_server = mock('http server')
        @mock_http_server.stubs(:listen)
        @server.stubs(:http_server).returns(@mock_http_server)
    end

    it "should indicate that it is not listening" do
        @server.should_not be_listening
    end  

    it "should not allow listening to be turned off" do
        lambda { @server.unlisten }.should raise_error(RuntimeError)
    end

    it "should allow listening to be turned on" do
        lambda { @server.listen }.should_not raise_error
    end

end

describe Puppet::Network::Server, "when listening is on" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @mock_http_server = mock('http server')
        @mock_http_server.stubs(:listen)
        @mock_http_server.stubs(:unlisten)
        @server.stubs(:http_server).returns(@mock_http_server)
        @server.listen
    end

    it "should indicate that it is listening" do
        @server.should be_listening
    end

    it "should not allow listening to be turned on" do
        lambda { @server.listen }.should raise_error(RuntimeError)
    end

    it "should allow listening to be turned off" do
        lambda { @server.unlisten }.should_not raise_error
    end
end

describe Puppet::Network::Server, "when listening is being turned on" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)

        Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')
        Puppet::Network::Handler.stubs(:handler).returns mock('xmlrpc_handler')

        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337, :handlers => [:node], :xmlrpc_handlers => [:master])
        @mock_http_server = mock('http server')
        @mock_http_server.stubs(:listen)
    end

    it "should fetch an instance of an HTTP server" do
        @server.stubs(:http_server_class).returns(@mock_http_server_class)
        @mock_http_server_class.expects(:new).returns(@mock_http_server)
        @server.listen        
    end

    it "should cause the HTTP server to listen" do
        @server.stubs(:http_server).returns(@mock_http_server)
        @mock_http_server.expects(:listen)
        @server.listen
    end

    it "should pass the listening address to the HTTP server" do
       @server.stubs(:http_server).returns(@mock_http_server)
       @mock_http_server.expects(:listen).with do |args|
           args[:address] == '127.0.0.1'
       end
       @server.listen
    end

    it "should pass the listening port to the HTTP server" do
        @server.stubs(:http_server).returns(@mock_http_server)
        @mock_http_server.expects(:listen).with do |args|
            args[:port] == 31337
        end
        @server.listen
    end

    it "should pass a list of REST handlers to the HTTP server" do
        @server.stubs(:http_server).returns(@mock_http_server)
        @mock_http_server.expects(:listen).with do |args|
            args[:handlers] == [ :node ]
        end
        @server.listen
    end

    it "should pass a list of XMLRPC handlers to the HTTP server" do
        @server.stubs(:http_server).returns(@mock_http_server)
        @mock_http_server.expects(:listen).with do |args|
            p args
            args[:xmlrpc_handlers] == [ :master ]
        end
        @server.listen
    end

    it "should pass a list of protocols to the HTTP server" do
        @server.stubs(:http_server).returns(@mock_http_server)
        @mock_http_server.expects(:listen).with do |args|
           args[:protocols] == [ :rest, :xmlrpc ]
        end
        @server.listen      
    end
end

describe Puppet::Network::Server, "when listening is being turned off" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @mock_http_server = mock('http server')
        @mock_http_server.stubs(:listen)
        @server.stubs(:http_server).returns(@mock_http_server)
        @server.listen
    end

    it "should cause the HTTP server to stop listening" do
        @mock_http_server.expects(:unlisten)
        @server.unlisten
    end

    it "should not allow for indirections to be turned off" do
        Puppet::Indirector::Indirection.stubs(:model).returns mock('indirection')

        @server.register(:foo)
        lambda { @server.unregister(:foo) }.should raise_error(RuntimeError) 
    end
end


describe Class.new, "put these somewhere" do
    it "should have the ability to use a class-level from_ hook (from_yaml, from_text, etc.) that can be called, based on content-type header, to allow for different deserializations of an object" 
    it "should allow from_* on the inbound :data packet (look at its content_type) when doing a PUT/.new.save"
    it "should prepend a rest version number on the path (w00t)"
    it "should ... on server side, .save should from_yaml, then foo.save(args) instead of just Foo.new.save(args)"
end
