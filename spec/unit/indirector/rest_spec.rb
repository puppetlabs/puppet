#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/indirector/rest'

shared_examples_for "a REST http call" do
  it "should accept a path" do
    lambda { @search.send(@method, *@arguments) }.should_not raise_error(ArgumentError)
  end

  it "should require a path" do
    lambda { @searcher.send(@method) }.should raise_error(ArgumentError)
  end

  it "should return the results of deserializing the response to the request" do
    conn = mock 'connection'
    conn.stubs(:put).returns @response
    conn.stubs(:delete).returns @response
    conn.stubs(:get).returns @response
    Puppet::Network::HttpPool.stubs(:http_instance).returns conn

    @searcher.expects(:deserialize).with(@response).returns "myobject"

    @searcher.send(@method, *@arguments).should == 'myobject'
  end
end

describe Puppet::Indirector::REST do
  before :all do
    Puppet::Indirector::Terminus.stubs(:register_terminus_class)
    @model = stub('model', :supported_formats => %w{}, :convert_from => nil)
    @instance = stub('model instance', :name= => nil)
    @indirection = stub('indirection', :name => :mystuff, :register_terminus_type => nil, :model => @model)
    Puppet::Indirector::Indirection.expects(:instance).returns(@indirection)

    module This
      module Is
        module A
          module Test
          end
        end
      end
    end
    @rest_class = class This::Is::A::Test::Class < Puppet::Indirector::REST
      self
    end
  end

  before :each do
    @response = stub('mock response', :body => 'result', :code => "200")
    @response.stubs(:[]).with('content-type').returns "text/plain"
    @response.stubs(:[]).with('content-encoding').returns nil

    @searcher = @rest_class.new
    @searcher.stubs(:model).returns @model
  end

  it "should include the v1 REST API module" do
    Puppet::Indirector::REST.ancestors.should be_include(Puppet::Network::HTTP::API::V1)
  end

  it "should have a method for specifying what setting a subclass should use to retrieve its server" do
    @rest_class.should respond_to(:use_server_setting)
  end

  it "should use any specified setting to pick the server" do
    @rest_class.expects(:server_setting).returns :servset
    Puppet.settings.expects(:value).with(:servset).returns "myserver"
    @rest_class.server.should == "myserver"
  end

  it "should default to :server for the server setting" do
    @rest_class.expects(:server_setting).returns nil
    Puppet.settings.expects(:value).with(:server).returns "myserver"
    @rest_class.server.should == "myserver"
  end

  it "should have a method for specifying what setting a subclass should use to retrieve its port" do
    @rest_class.should respond_to(:use_port_setting)
  end

  it "should use any specified setting to pick the port" do
    @rest_class.expects(:port_setting).returns :servset
    Puppet.settings.expects(:value).with(:servset).returns "321"
    @rest_class.port.should == 321
  end

  it "should default to :port for the port setting" do
    @rest_class.expects(:port_setting).returns nil
    Puppet.settings.expects(:value).with(:masterport).returns "543"
    @rest_class.port.should == 543
  end

  describe "when making http requests" do
    include PuppetSpec::Files

    it "should provide a suggestive error message when certificate verify failed" do
      connection = Net::HTTP.new('my_server', 8140)
      @searcher.stubs(:network).returns(connection)

      connection.stubs(:get).raises(OpenSSL::SSL::SSLError.new('certificate verify failed'))

      expect do
        @searcher.http_request(:get, stub('request'))
      end.to raise_error(/This is often because the time is out of sync on the server or client/)
    end

    it "should provide a helpful error message when hostname was not match with server certificate", :unless => Puppet.features.microsoft_windows? do
      Puppet[:confdir] = tmpdir('conf')
      cert = Puppet::SSL::CertificateAuthority.new.generate('not_my_server', :dns_alt_names => 'foo,bar,baz').content

      connection = Net::HTTP.new('my_server', 8140)
      @searcher.stubs(:network).returns(connection)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_context.stubs(:current_cert).returns(cert)
      connection.stubs(:get).with do
        connection.verify_callback.call(true, ssl_context)
      end.raises(OpenSSL::SSL::SSLError.new('hostname was not match with server certificate'))

      msg = /Server hostname 'my_server' did not match server certificate; expected one of (.+)/
      expect { @searcher.http_request(:get, stub('request')) }.to(
        raise_error(Puppet::Error, msg) do |error|
          error.message =~ msg
          $1.split(', ').should =~ %w[DNS:foo DNS:bar DNS:baz DNS:not_my_server not_my_server]
        end
      )
    end

    it "should pass along the error message otherwise" do
      connection = Net::HTTP.new('my_server', 8140)
      @searcher.stubs(:network).returns(connection)

      connection.stubs(:get).raises(OpenSSL::SSL::SSLError.new('some other message'))

      expect do
        @searcher.http_request(:get, stub('request'))
      end.to raise_error(/some other message/)
    end
  end

  describe "when deserializing responses" do
    it "should return nil if the response code is 404" do
      response = mock 'response'
      response.expects(:code).returns "404"

      @searcher.deserialize(response).should be_nil
    end

    [300,400,403,405,500,501,502,503,504].each { |rc|
      describe "when the response code is #{rc}" do
        before :each do
          @model.expects(:convert_from).never

          @response = mock 'response'
          @response.stubs(:code).returns rc.to_s
          @response.stubs(:[]).with('content-encoding').returns nil
          @response.stubs(:message).returns "There was a problem (header)"
        end

        it "should fail" do
          @response.stubs(:body).returns nil
          lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError)
        end

        it "should take the error message from the body, if present" do
          @response.stubs(:body).returns "There was a problem (body)"
          lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (body)")
        end

        it "should take the error message from the response header if the body is empty" do
          @response.stubs(:body).returns ""
          lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (header)")
        end

        it "should take the error message from the response header if the body is absent" do
          @response.stubs(:body).returns nil
          lambda { @searcher.deserialize(@response) }.should raise_error(Net::HTTPError,"Error #{rc} on SERVER: There was a problem (header)")
        end

        describe "and with http compression" do
          it "should uncompress the body" do
            @response.stubs(:body).returns("compressed body")
            @searcher.expects(:uncompress_body).with(@response).returns("uncompressed")
            lambda { @searcher.deserialize(@response) }.should raise_error { |e| e.message =~ /uncompressed/ }
          end
        end
      end
    }

    it "should return the results of converting from the format specified by the content-type header if the response code is in the 200s" do
      @model.expects(:convert_from).with("myformat", "mydata").returns "myobject"

      response = mock 'response'
      response.stubs(:[]).with("content-type").returns "myformat"
      response.stubs(:[]).with("content-encoding").returns nil
      response.stubs(:body).returns "mydata"
      response.stubs(:code).returns "200"

      @searcher.deserialize(response).should == "myobject"
    end

    it "should convert and return multiple instances if the return code is in the 200s and 'multiple' is specified" do
      @model.expects(:convert_from_multiple).with("myformat", "mydata").returns "myobjects"

      response = mock 'response'
      response.stubs(:[]).with("content-type").returns "myformat"
      response.stubs(:[]).with("content-encoding").returns nil
      response.stubs(:body).returns "mydata"
      response.stubs(:code).returns "200"

      @searcher.deserialize(response, true).should == "myobjects"
    end

    it "should strip the content-type header to keep only the mime-type" do
      @model.expects(:convert_from).with("text/plain", "mydata").returns "myobject"

      response = mock 'response'
      response.stubs(:[]).with("content-type").returns "text/plain; charset=utf-8"
      response.stubs(:[]).with("content-encoding").returns nil
      response.stubs(:body).returns "mydata"
      response.stubs(:code).returns "200"

      @searcher.deserialize(response)
    end

    it "should uncompress the body" do
      @model.expects(:convert_from).with("myformat", "uncompressed mydata").returns "myobject"

      response = mock 'response'
      response.stubs(:[]).with("content-type").returns "myformat"
      response.stubs(:body).returns "compressed mydata"
      response.stubs(:code).returns "200"

      @searcher.expects(:uncompress_body).with(response).returns("uncompressed mydata")

      @searcher.deserialize(response).should == "myobject"
    end
  end

  describe "when creating an HTTP client" do
    before do
      Puppet.settings.stubs(:value).returns("rest_testing")
    end

    it "should use the class's server and port if the indirection request provides neither" do
      @request = stub 'request', :key => "foo", :server => nil, :port => nil
      @searcher.class.expects(:port).returns 321
      @searcher.class.expects(:server).returns "myserver"
      Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
      @searcher.network(@request).should == "myconn"
    end

    it "should use the server from the indirection request if one is present" do
      @request = stub 'request', :key => "foo", :server => "myserver", :port => nil
      @searcher.class.stubs(:port).returns 321
      Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
      @searcher.network(@request).should == "myconn"
    end

    it "should use the port from the indirection request if one is present" do
      @request = stub 'request', :key => "foo", :server => nil, :port => 321
      @searcher.class.stubs(:server).returns "myserver"
      Puppet::Network::HttpPool.expects(:http_instance).with("myserver", 321).returns "myconn"
      @searcher.network(@request).should == "myconn"
    end
  end

  describe "when doing a find" do
    before :each do
      @connection = stub('mock http connection', :get => @response, :verify_callback= => nil)
      @searcher.stubs(:network).returns(@connection)    # neuter the network connection

      # Use a key with spaces, so we can test escaping
      @request = Puppet::Indirector::Request.new(:foo, :find, "foo bar", :environment => "myenv")
    end

    describe "with a large body" do
      it "should use the POST http method" do
        params = {}
        'aa'.upto('zz') do |s|
          params[s] = 'foo'
        end

        # The request special-cases this parameter, and it
        # won't be passed on to the server, so we remove it here
        # to avoid a failure.
        params.delete('ip')

        @request = Puppet::Indirector::Request.new(:foo, :find, "foo bar", params.merge(:environment => "myenv"))

        @connection.expects(:post).with do |uri, body|
          uri == "/myenv/foo/foo%20bar" and body.split("&").sort == params.map {|key,value| "#{key}=#{value}"}.sort
        end.returns(@response)

        @searcher.find(@request)
      end
    end

    describe "with a small body" do
      it "should use the GET http method" do
        @searcher.expects(:network).returns @connection
        @connection.expects(:get).returns @response
        @searcher.find(@request)
      end
    end

    it "should deserialize and return the http response, setting name" do
      @connection.expects(:get).returns @response

      instance = stub 'object'
      instance.expects(:name=)
      @searcher.expects(:deserialize).with(@response).returns instance

      @searcher.find(@request).should == instance
    end

    it "should deserialize and return the http response, and not require name=" do
      @connection.expects(:get).returns @response

      instance = stub 'object'
      @searcher.expects(:deserialize).with(@response).returns instance

      @searcher.find(@request).should == instance
    end

    it "should use the URI generated by the Handler module" do
      @connection.expects(:get).with { |path, args| path == "/myenv/foo/foo%20bar?" }.returns(@response)
      @searcher.find(@request)
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      @connection.expects(:get).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

      @searcher.model.expects(:supported_formats).returns %w{supported formats}
      @searcher.find(@request)
    end

    it "should add Accept-Encoding header" do
      @searcher.expects(:add_accept_encoding).returns({"accept-encoding" => "gzip"})

      @connection.expects(:get).with { |path, args| args["accept-encoding"] == "gzip" }.returns(@response)
      @searcher.find(@request)
    end

    it "should deserialize and return the network response" do
      @searcher.expects(:deserialize).with(@response).returns @instance
      @searcher.find(@request).should equal(@instance)
    end

    it "should set the name of the resulting instance to the asked-for name" do
      @searcher.expects(:deserialize).with(@response).returns @instance
      @instance.expects(:name=).with "foo bar"
      @searcher.find(@request)
    end

    it "should generate an error when result data deserializes fails" do
      @searcher.expects(:deserialize).raises(ArgumentError)
      lambda { @searcher.find(@request) }.should raise_error(ArgumentError)
    end
  end

  describe "when doing a head" do
    before :each do
      @connection = stub('mock http connection', :head => @response, :verify_callback= => nil)
      @searcher.stubs(:network).returns(@connection)

      # Use a key with spaces, so we can test escaping
      @request = Puppet::Indirector::Request.new(:foo, :head, "foo bar")
    end

    it "should call the HEAD http method on a network connection" do
      @searcher.expects(:network).returns @connection
      @connection.expects(:head).returns @response
      @searcher.head(@request)
    end

    it "should return true if there was a successful http response" do
      @connection.expects(:head).returns @response
      @response.stubs(:code).returns "200"

      @searcher.head(@request).should == true
    end

    it "should return false if there was a successful http response" do
      @connection.expects(:head).returns @response
      @response.stubs(:code).returns "404"

      @searcher.head(@request).should == false
    end

    it "should use the URI generated by the Handler module" do
      @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
      @connection.expects(:head).with { |path, args| path == "/my/uri" }.returns(@response)
      @searcher.head(@request)
    end
  end

  describe "when doing a search" do
    before :each do
      @connection = stub('mock http connection', :get => @response, :verify_callback= => nil)
      @searcher.stubs(:network).returns(@connection)    # neuter the network connection

      @model.stubs(:convert_from_multiple)

      @request = Puppet::Indirector::Request.new(:foo, :search, "foo bar")
    end

    it "should call the GET http method on a network connection" do
      @searcher.expects(:network).returns @connection
      @connection.expects(:get).returns @response
      @searcher.search(@request)
    end

    it "should deserialize as multiple instances and return the http response" do
      @connection.expects(:get).returns @response
      @searcher.expects(:deserialize).with(@response, true).returns "myobject"

      @searcher.search(@request).should == 'myobject'
    end

    it "should use the URI generated by the Handler module" do
      @searcher.expects(:indirection2uri).with(@request).returns "/mys/uri"
      @connection.expects(:get).with { |path, args| path == "/mys/uri" }.returns(@response)
      @searcher.search(@request)
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      @connection.expects(:get).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

      @searcher.model.expects(:supported_formats).returns %w{supported formats}
      @searcher.search(@request)
    end

    it "should return an empty array if serialization returns nil" do
      @model.stubs(:convert_from_multiple).returns nil

      @searcher.search(@request).should == []
    end

    it "should generate an error when result data deserializes fails" do
      @searcher.expects(:deserialize).raises(ArgumentError)
      lambda { @searcher.search(@request) }.should raise_error(ArgumentError)
    end
  end

  describe "when doing a destroy" do
    before :each do
      @connection = stub('mock http connection', :delete => @response, :verify_callback= => nil)
      @searcher.stubs(:network).returns(@connection)    # neuter the network connection

      @request = Puppet::Indirector::Request.new(:foo, :destroy, "foo bar")
    end

    it "should call the DELETE http method on a network connection" do
      @searcher.expects(:network).returns @connection
      @connection.expects(:delete).returns @response
      @searcher.destroy(@request)
    end

    it "should fail if any options are provided, since DELETE apparently does not support query options" do
      @request.stubs(:options).returns(:one => "two", :three => "four")

      lambda { @searcher.destroy(@request) }.should raise_error(ArgumentError)
    end

    it "should deserialize and return the http response" do
      @connection.expects(:delete).returns @response
      @searcher.expects(:deserialize).with(@response).returns "myobject"

      @searcher.destroy(@request).should == 'myobject'
    end

    it "should use the URI generated by the Handler module" do
      @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
      @connection.expects(:delete).with { |path, args| path == "/my/uri" }.returns(@response)
      @searcher.destroy(@request)
    end

    it "should not include the query string" do
      @connection.stubs(:delete).returns @response
      @searcher.destroy(@request)
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      @connection.expects(:delete).with { |path, args| args["Accept"] == "supported, formats" }.returns(@response)

      @searcher.model.expects(:supported_formats).returns %w{supported formats}
      @searcher.destroy(@request)
    end

    it "should deserialize and return the network response" do
      @searcher.expects(:deserialize).with(@response).returns @instance
      @searcher.destroy(@request).should equal(@instance)
    end

    it "should generate an error when result data deserializes fails" do
      @searcher.expects(:deserialize).raises(ArgumentError)
      lambda { @searcher.destroy(@request) }.should raise_error(ArgumentError)
    end
  end

  describe "when doing a save" do
    before :each do
      @connection = stub('mock http connection', :put => @response, :verify_callback= => nil)
      @searcher.stubs(:network).returns(@connection)    # neuter the network connection

      @instance = stub 'instance', :render => "mydata", :mime => "mime"
      @request = Puppet::Indirector::Request.new(:foo, :save, "foo bar")
      @request.instance = @instance
    end

    it "should call the PUT http method on a network connection" do
      @searcher.expects(:network).returns @connection
      @connection.expects(:put).returns @response
      @searcher.save(@request)
    end

    it "should fail if any options are provided, since DELETE apparently does not support query options" do
      @request.stubs(:options).returns(:one => "two", :three => "four")

      lambda { @searcher.save(@request) }.should raise_error(ArgumentError)
    end

    it "should use the URI generated by the Handler module" do
      @searcher.expects(:indirection2uri).with(@request).returns "/my/uri"
      @connection.expects(:put).with { |path, args| path == "/my/uri" }.returns(@response)
      @searcher.save(@request)
    end

    it "should serialize the instance using the default format and pass the result as the body of the request" do
      @instance.expects(:render).returns "serial_instance"
      @connection.expects(:put).with { |path, data, args| data == "serial_instance" }.returns @response

      @searcher.save(@request)
    end

    it "should deserialize and return the http response" do
      @connection.expects(:put).returns @response
      @searcher.expects(:deserialize).with(@response).returns "myobject"

      @searcher.save(@request).should == 'myobject'
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      @connection.expects(:put).with { |path, data, args| args["Accept"] == "supported, formats" }.returns(@response)

      @searcher.model.expects(:supported_formats).returns %w{supported formats}
      @searcher.save(@request)
    end

    it "should provide a Content-Type header containing the mime-type of the sent object" do
      @connection.expects(:put).with { |path, data, args| args['Content-Type'] == "mime" }.returns(@response)

      @instance.expects(:mime).returns "mime"
      @searcher.save(@request)
    end

    it "should deserialize and return the network response" do
      @searcher.expects(:deserialize).with(@response).returns @instance
      @searcher.save(@request).should equal(@instance)
    end

    it "should generate an error when result data deserializes fails" do
      @searcher.expects(:deserialize).raises(ArgumentError)
      lambda { @searcher.save(@request) }.should raise_error(ArgumentError)
    end
  end
end
