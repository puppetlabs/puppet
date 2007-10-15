#!/usr/bin/env ruby
#
#  Created by Rick Bradley on 2007-10-03.
#  Copyright (c) 2007. All rights reserved.

require File.dirname(__FILE__) + '/../../spec_helper'
require 'puppet/network/server'

describe Puppet::Network::Server, "when initializing" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
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
        Proc.new { Puppet::Network::Server.new }.should raise_error(ArgumentError)
    end
    
    it "should fail to initialize if no listening port can be found" do
        Puppet.stubs(:[]).with(:bindaddress).returns("127.0.0.1")
        Puppet.stubs(:[]).with(:masterport).returns(nil)
        Proc.new { Puppet::Network::Server.new }.should raise_error(ArgumentError)        
    end

    it "should use the Puppet configurator to determine which HTTP server will be used to provide access to clients" do
        Puppet.expects(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @server.server_type.should == :suparserver
    end
  
    it "should fail to initialize if there is no HTTP server known to the Puppet configurator" do
        Puppet.expects(:[]).with(:servertype).returns(nil)
        Proc.new { Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337) }.should raise_error
    end
 
    it "should ask the Puppet::Network::HTTP class to fetch the proper HTTP server class" do
        mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.expects(:server_class_by_type).with(:suparserver).returns(mock_http_server_class)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
    end
  
    it "should allow registering indirections" do
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337, :handlers => [ :foo, :bar, :baz])
        Proc.new { @server.unregister(:foo, :bar, :baz) }.should_not raise_error
    end
  
    it "should not be listening after initialization" do
        Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337).should_not be_listening
    end
end

describe Puppet::Network::Server, "in general" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
    end
  
    it "should allow registering an indirection for client access by specifying its indirection name" do
        Proc.new { @server.register(:foo) }.should_not raise_error
    end
  
    it "should require at least one indirection name when registering indirections for client access" do
        Proc.new { @server.register }.should raise_error(ArgumentError)
    end
  
    it "should allow for numerous indirections to be registered at once for client access" do
        Proc.new { @server.register(:foo, :bar, :baz) }.should_not raise_error
    end

    it "should allow the use of indirection names to specify which indirections are to be no longer accessible to clients" do
        @server.register(:foo)
        Proc.new { @server.unregister(:foo) }.should_not raise_error    
    end

    it "should leave other indirections accessible to clients when turning off indirections" do
        @server.register(:foo, :bar)
        @server.unregister(:foo)
        Proc.new { @server.unregister(:bar)}.should_not raise_error
    end
  
    it "should allow specifying numerous indirections which are to be no longer accessible to clients" do
        @server.register(:foo, :bar)
        Proc.new { @server.unregister(:foo, :bar) }.should_not raise_error
    end
    
    it "should not turn off any indirections if given unknown indirection names to turn off" do
        @server.register(:foo, :bar)
        Proc.new { @server.unregister(:foo, :bar, :baz) }.should raise_error(ArgumentError)
        Proc.new { @server.unregister(:foo, :bar) }.should_not raise_error
    end
  
    it "should not allow turning off unknown indirection names" do
        @server.register(:foo, :bar)
        Proc.new { @server.unregister(:baz) }.should raise_error(ArgumentError)
    end
  
    it "should disable client access immediately when turning off indirections" do
        @server.register(:foo, :bar)
        @server.unregister(:foo)    
        Proc.new { @server.unregister(:foo) }.should raise_error(ArgumentError)
    end
  
    it "should allow turning off all indirections at once" do
        @server.register(:foo, :bar)
        @server.unregister
        [ :foo, :bar, :baz].each do |indirection|
            Proc.new { @server.unregister(indirection) }.should raise_error(ArgumentError)
        end
    end
  
    it "should provide a means of determining whether it is listening" do
        @server.should respond_to(:listening?)
    end
  
    it "should provide a means of determining which HTTP server will be used to provide access to clients" do
        @server.server_type.should == :suparserver
    end
    
    it "should allow for multiple configurations, each handling different indirections" do
        @server2 = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @server.register(:foo, :bar)
        @server2.register(:foo, :xyzzy)
        @server.unregister(:foo, :bar)
        @server2.unregister(:foo, :xyzzy)
        Proc.new { @server.unregister(:xyzzy) }.should raise_error(ArgumentError)
        Proc.new { @server2.unregister(:bar) }.should raise_error(ArgumentError)
    end  

    it "should provide a means of determining which style of service is being offered to clients" do
        @server.protocols.should == []
    end
    
    it "should provide a means of determining the listening address" do
        @server.address.should == "127.0.0.1"
    end
    
    it "should provide a means of determining the listening port" do
        @server.port.should == 31337
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
        Proc.new { @server.unlisten }.should raise_error(RuntimeError)
    end
  
    it "should allow listening to be turned on" do
        Proc.new { @server.listen }.should_not raise_error
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
  
    it "should indicate that listening is turned off" do
        @server.should be_listening
    end
    
    it "should not allow listening to be turned on" do
        Proc.new { @server.listen }.should raise_error(RuntimeError)
    end
  
    it "should allow listening to be turned off" do
        Proc.new { @server.unlisten }.should_not raise_error
    end
end
 
describe Puppet::Network::Server, "when listening is being turned on" do
    before do
        @mock_http_server_class = mock('http server class')
        Puppet::Network::HTTP.stubs(:server_class_by_type).returns(@mock_http_server_class)
        Puppet.stubs(:[]).with(:servertype).returns(:suparserver)
        @server = Puppet::Network::Server.new(:address => "127.0.0.1", :port => 31337)
        @mock_http_server = mock('http server')
        @mock_http_server.stubs(:listen)
    end

    it "should fetch an instance of an HTTP server when listening is turned on" do
        mock_http_server_class = mock('http server class')
        mock_http_server_class.expects(:new).returns(@mock_http_server)
        @server.expects(:http_server_class).returns(mock_http_server_class)
        @server.listen        
    end

    it "should cause the HTTP server to listen when listening is turned on" do
        @mock_http_server.expects(:listen)
        @server.expects(:http_server).returns(@mock_http_server)
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

    it "should cause the HTTP server to stop listening when listening is turned off" do
        @mock_http_server.expects(:unlisten)
        @server.unlisten
    end

    it "should not allow for indirections to be turned off" do
        @server.register(:foo)
        Proc.new { @server.unregister(:foo) }.should raise_error(RuntimeError) 
    end
end

describe Class.new, "Puppet::Network::Handler::*::* (handler class (e.g., webrick+rest or mongrel+xmlrpc))" do
    it "should be able to unserialize a request from the given httpserver answering for the given protocol handler, to be used by a controller"
    it "should be able to serialize a result from a controller for return by the given httpserver responding with the given protocol"
    it "should properly encode an exception from a controller for use by the httpserver for the given protocol handler"
    it "should call the appropriate controller method"
    it "should properly encode parameters on the request for use by the controller methods"
end

describe Class.new, "put these somewhere" do
    it "should allow indirections to deny access to services based upon which client is connecting, or whether the client is authorized"
    it "should deny access to clients based upon rules"    
end


