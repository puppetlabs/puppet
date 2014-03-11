#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'
require 'webrick'
require 'puppet/network/http/webrick/rest'

describe Puppet::Network::HTTP::WEBrickREST do
  it "should include the Puppet::Network::HTTP::Handler module" do
    Puppet::Network::HTTP::WEBrickREST.ancestors.should be_include(Puppet::Network::HTTP::Handler)
  end

  describe "when receiving a request" do
    before do
      @request     = stub('webrick http request', :query => {}, :peeraddr => %w{eh boo host ip}, :client_cert => nil)
      @response    = mock('webrick http response')
      @model_class = stub('indirected model class')
      @webrick     = stub('webrick http server', :mount => true, :[] => {})
      Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@model_class)
      @handler = Puppet::Network::HTTP::WEBrickREST.new(@webrick)
    end

    it "should delegate its :service method to its :process method" do
      @handler.expects(:process).with(@request, @response).returns "stuff"
      @handler.service(@request, @response).should == "stuff"
    end

    describe "#headers" do
      let(:fake_request) { {"Foo" => "bar", "BAZ" => "bam" } }

      it "should iterate over the request object using #each" do
        fake_request.expects(:each)
        @handler.headers(fake_request)
      end

      it "should return a hash with downcased header names" do
        result = @handler.headers(fake_request)
        result.should == fake_request.inject({}) { |m,(k,v)| m[k.downcase] = v; m }
      end
    end

    describe "when using the Handler interface" do
      it "should use the request method as the http method" do
        @request.expects(:request_method).returns "FOO"
        @handler.http_method(@request).should == "FOO"
      end

      it "should return the request path as the path" do
        @request.expects(:path).returns "/foo/bar"
        @handler.path(@request).should == "/foo/bar"
      end

      it "should return the request body as the body" do
        @request.expects(:body).returns "my body"
        @handler.body(@request).should == "my body"
      end

      it "should set the response's 'content-type' header when setting the content type" do
        @response.expects(:[]=).with("content-type", "text/html")
        @handler.set_content_type(@response, "text/html")
      end

      it "should set the status and body on the response when setting the response for a successful query" do
        @response.expects(:status=).with 200
        @response.expects(:body=).with "mybody"

        @handler.set_response(@response, "mybody", 200)
      end

      it "serves a file" do
        stat = stub 'stat', :size => 100
        @file = stub 'file', :stat => stat, :path => "/tmp/path"
        @file.stubs(:is_a?).with(File).returns(true)

        @response.expects(:[]=).with('content-length', 100)
        @response.expects(:status=).with 200
        @response.expects(:body=).with @file

        @handler.set_response(@response, @file, 200)
      end

      it "should set the status and message on the response when setting the response for a failed query" do
        @response.expects(:status=).with 400
        @response.expects(:body=).with "mybody"

        @handler.set_response(@response, "mybody", 400)
      end
    end

    describe "and determining the request parameters" do
      def query_of(options)
        request = Puppet::Indirector::Request.new(:myind, :find, "my key", nil, options)
        WEBrick::HTTPUtils.parse_query(request.query_string.sub(/^\?/, ''))
      end

      def a_request_querying(query_data)
        @request.expects(:query).returns(query_of(query_data))
        @request
      end

      def certificate_with_subject(subj)
        cert = OpenSSL::X509::Certificate.new
        cert.subject = OpenSSL::X509::Name.parse(subj)
        cert
      end

      it "has no parameters when there is no query string" do
        only_server_side_information = [:authenticated, :ip, :node]
        @request.stubs(:query).returns(nil)

        result = @handler.params(@request)

        result.keys.sort.should == only_server_side_information
      end

      it "should include the HTTP request parameters, with the keys as symbols" do
        request = a_request_querying("foo" => "baz", "bar" => "xyzzy")
        result = @handler.params(request)

        result[:foo].should == "baz"
        result[:bar].should == "xyzzy"
      end

      it "should handle parameters with no value" do
        request = a_request_querying('foo' => "")

        result = @handler.params(request)

        result[:foo].should == ""
      end

      it "should convert the string 'true' to the boolean" do
        request = a_request_querying('foo' => "true")

        result = @handler.params(request)

        result[:foo].should == true
      end

      it "should convert the string 'false' to the boolean" do
        request = a_request_querying('foo' => "false")

        result = @handler.params(request)

        result[:foo].should == false
      end

      it "should reconstruct arrays" do
        request = a_request_querying('foo' => ["a", "b", "c"])

        result = @handler.params(request)

        result[:foo].should == ["a", "b", "c"]
      end

      it "should convert values inside arrays into primitive types" do
        request = a_request_querying('foo' => ["true", "false", "1", "1.2"])

        result = @handler.params(request)

        result[:foo].should == [true, false, 1, 1.2]
      end

      it "should YAML-load values that are YAML-encoded" do
        request = a_request_querying('foo' => YAML.dump(%w{one two}))

        result = @handler.params(request)

        result[:foo].should == %w{one two}
      end

      it "should YAML-load that are YAML-encoded" do
        request = a_request_querying('foo' => YAML.dump(%w{one two}))

        result = @handler.params(request)

        result[:foo].should == %w{one two}
      end

      it "should not allow clients to set the node via the request parameters" do
        request = a_request_querying("node" => "foo")
        @handler.stubs(:resolve_node)

        @handler.params(request)[:node].should be_nil
      end

      it "should not allow clients to set the IP via the request parameters" do
        request = a_request_querying("ip" => "foo")

        @handler.params(request)[:ip].should_not == "foo"
      end

      it "should pass the client's ip address to model find" do
        @request.stubs(:peeraddr).returns(%w{noidea dunno hostname ipaddress})
        @handler.params(@request)[:ip].should == "ipaddress"
      end

      it "should set 'authenticated' to true if a certificate is present" do
        cert = stub 'cert', :subject => [%w{CN host.domain.com}]
        @request.stubs(:client_cert).returns cert
        @handler.params(@request)[:authenticated].should be_true
      end

      it "should set 'authenticated' to false if no certificate is present" do
        @request.stubs(:client_cert).returns nil
        @handler.params(@request)[:authenticated].should be_false
      end

      it "should pass the client's certificate name to model method if a certificate is present" do
        @request.stubs(:client_cert).returns(certificate_with_subject("/CN=host.domain.com"))

        @handler.params(@request)[:node].should == "host.domain.com"
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        @request.stubs(:client_cert).returns nil

        @handler.expects(:resolve_node).returns(:resolved_node)

        @handler.params(@request)[:node].should == :resolved_node
      end

      it "should resolve the node name with an ip address look-up if CN parsing fails" do
        @request.stubs(:client_cert).returns(certificate_with_subject("/C=company"))

        @handler.expects(:resolve_node).returns(:resolved_node)

        @handler.params(@request)[:node].should == :resolved_node
      end
    end
  end
end
