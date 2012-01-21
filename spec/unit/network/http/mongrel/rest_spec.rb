#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/network/http'

describe "Puppet::Network::HTTP::MongrelREST", :if => Puppet.features.mongrel?, :'fails_on_ruby_1.9.2' => true do
  before do
    require 'puppet/network/http/mongrel/rest'
  end


  it "should include the Puppet::Network::HTTP::Handler module" do
    Puppet::Network::HTTP::MongrelREST.ancestors.should be_include(Puppet::Network::HTTP::Handler)
  end

  describe "when initializing" do
    it "should call the Handler's initialization hook with its provided arguments as the server and handler" do
      Puppet::Network::HTTP::MongrelREST.any_instance.expects(:initialize_for_puppet).with(:server => "my", :handler => "arguments")
      Puppet::Network::HTTP::MongrelREST.new(:server => "my", :handler => "arguments")
    end
  end

  describe "when receiving a request" do
    before do
      @params = {}
      @request = stub('mongrel http request', :params => @params)

      @head = stub('response head')
      @body = stub('response body', :write => true)
      @response = stub('mongrel http response')
      @response.stubs(:start).yields(@head, @body)
      @model_class = stub('indirected model class')
      @mongrel = stub('mongrel http server', :register => true)
      Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@model_class)
      @handler = Puppet::Network::HTTP::MongrelREST.new(:server => @mongrel, :handler => :foo)
    end

    describe "and using the HTTP Handler interface" do
      it "should return the HTTP_ACCEPT parameter as the accept header" do
        @params.expects(:[]).with("HTTP_ACCEPT").returns "myaccept"
        @handler.accept_header(@request).should == "myaccept"
      end

      it "should return the Content-Type parameter as the Content-Type header" do
        @params.expects(:[]).with("HTTP_CONTENT_TYPE").returns "mycontent"
        @handler.content_type_header(@request).should == "mycontent"
      end

      it "should use the REQUEST_METHOD as the http method" do
        @params.expects(:[]).with(Mongrel::Const::REQUEST_METHOD).returns "mymethod"
        @handler.http_method(@request).should == "mymethod"
      end

      it "should return the request path as the path" do
        @params.expects(:[]).with(Mongrel::Const::REQUEST_PATH).returns "/foo/bar"
        @handler.path(@request).should == "/foo/bar"
      end

      it "should return the request body as the body" do
        @request.stubs(:body).returns StringIO.new("mybody")
        @handler.body(@request).should == "mybody"
      end

      it "should set the response's content-type header when setting the content type" do
        @header = mock 'header'
        @response.expects(:header).returns @header
        @header.expects(:[]=).with('Content-Type', "mytype")

        @handler.set_content_type(@response, "mytype")
      end

      it "should set the status and write the body when setting the response for a successful request" do
        head = mock 'head'
        body = mock 'body'
        @response.expects(:start).with(200).yields(head, body)

        body.expects(:write).with("mybody")

        @handler.set_response(@response, "mybody", 200)
      end

      describe "when the result is a File" do
        it "should use response send_file" do
          head = mock 'head'
          body = mock 'body'
          stat = stub 'stat', :size => 100
          file = stub 'file', :stat => stat, :path => "/tmp/path"
          file.stubs(:is_a?).with(File).returns(true)

          @response.expects(:start).with(200).yields(head, body)
          @response.expects(:send_status).with(100)
          @response.expects(:send_header)
          @response.expects(:send_file).with("/tmp/path")

          @handler.set_response(@response, file, 200)
        end
      end

      it "should set the status and reason and write the body when setting the response for a successful request" do
        head = mock 'head'
        body = mock 'body'
        @response.expects(:start).with(400, false, "mybody").yields(head, body)

        body.expects(:write).with("mybody")

        @handler.set_response(@response, "mybody", 400)
      end
    end

    describe "and determining the request parameters" do
      before do
        @params = {'REQUEST_METHOD' => 'GET'}
        @request.stubs(:params).returns(@params)
      end

      it "should skip empty parameter values" do
        @params['QUERY_STRING'] = "&="
        lambda { @handler.params(@request) }.should_not raise_error
      end

      it "should include the HTTP request parameters, with the keys as symbols" do
        @params['QUERY_STRING'] = 'foo=baz&bar=xyzzy'
        result = @handler.params(@request)
        result[:foo].should == "baz"
        result[:bar].should == "xyzzy"
      end

      it "should CGI-decode the HTTP parameters" do
        escaped = CGI.escape("foo bar")
        @params['QUERY_STRING'] = "foo=#{escaped}"
        result = @handler.params(@request)
        result[:foo].should == "foo bar"
      end

      it "should include parameters from the body of a POST request" do
        @params.merge!(
          'QUERY_STRING'   => nil,
          'REQUEST_METHOD' => 'POST'
        )
        body = StringIO.new('foo=bar&baz=qux')
        @request.stubs(:body).returns(body)

        @handler.params(@request).should include(
          :foo => 'bar',
          :baz => 'qux'
        )
      end

      it "should convert the string 'true' to the boolean" do
        @params['QUERY_STRING'] = 'foo=true'
        result = @handler.params(@request)
        result[:foo].should be_true
      end

      it "should convert the string 'false' to the boolean" do
        @params['QUERY_STRING'] = 'foo=false'
        result = @handler.params(@request)
        result[:foo].should be_false
      end

      it "should convert integer arguments to Integers" do
        @params['QUERY_STRING'] = 'foo=15'
        result = @handler.params(@request)
        result[:foo].should == 15
      end

      it "should convert floating point arguments to Floats" do
        @params['QUERY_STRING'] = 'foo=1.5'
        result = @handler.params(@request)
        result[:foo].should == 1.5
      end

      it "should YAML-load and URI-decode values that are YAML-encoded" do
        escaping = CGI.escape(YAML.dump(%w{one two}))
        @params['QUERY_STRING'] = "foo=#{escaping}"
        result = @handler.params(@request)
        result[:foo].should == %w{one two}
      end

      it "should not allow the client to set the node via the query string" do
        @params['QUERY_STRING'] = "node=foo"
        @handler.params(@request)[:node].should be_nil
      end

      it "should not allow the client to set the IP address via the query string" do
        @params['QUERY_STRING'] = "ip=foo"
        @handler.params(@request)[:ip].should be_nil
      end

      it "should pass the client's ip address to model find" do
        @params['REMOTE_ADDR'] = "ipaddress"
        @handler.params(@request)[:ip].should == "ipaddress"
      end

      it "should pass the client's provided X-Forwared-For value as the ip" do
        @params["HTTP_X_FORWARDED_FOR"] = "ipaddress"
        @handler.params(@request)[:ip].should == "ipaddress"
      end

      it "should pass the client's provided X-Forwared-For first value as the ip" do
        @params["HTTP_X_FORWARDED_FOR"] = "ipproxy1,ipproxy2,ipaddress"
        @handler.params(@request)[:ip].should == "ipaddress"
      end

      it "should pass the client's provided X-Forwared-For value as the ip instead of the REMOTE_ADDR" do
        @params.merge!(
          "REMOTE_ADDR"          => "remote_addr",
          "HTTP_X_FORWARDED_FOR" => "ipaddress"
        )
        @handler.params(@request)[:ip].should == "ipaddress"
      end

      it "should use the :ssl_client_header to determine the parameter when looking for the certificate" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        @params["myheader"] = "/CN=host.domain.com"
        @handler.params(@request)
      end

      it "should retrieve the hostname by matching the certificate parameter" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        @params["myheader"] = "/CN=host.domain.com"
        @handler.params(@request)[:node].should == "host.domain.com"
      end

      it "should use the :ssl_client_header to determine the parameter for checking whether the host certificate is valid" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.expects(:value).with(:ssl_client_verify_header).returns "myheader"
        @params.merge!(
          "myheader"   => "SUCCESS",
          "certheader" => "/CN=host.domain.com"
        )
        @handler.params(@request)
      end

      it "should consider the host authenticated if the validity parameter contains 'SUCCESS'" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        @params.merge!(
          "myheader"   => "SUCCESS",
          "certheader" => "/CN=host.domain.com"
        )
        @handler.params(@request)[:authenticated].should be_true
      end

      it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        @params.merge!(
          "myheader"   => "whatever",
          "certheader" => "/CN=host.domain.com"
        )
        @handler.params(@request)[:authenticated].should be_false
      end

      it "should consider the host unauthenticated if no certificate information is present" do
        Puppet.settings.stubs(:value).with(:ssl_client_header).returns "certheader"
        Puppet.settings.stubs(:value).with(:ssl_client_verify_header).returns "myheader"
        @params.merge!(
          "myheader"   => nil,
          "certheader" => "SUCCESS"
        )
        @handler.params(@request)[:authenticated].should be_false
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        Puppet.settings.stubs(:value).returns "eh"
        Puppet.settings.expects(:value).with(:ssl_client_header).returns "myheader"
        @params["myheader"] = nil
        @handler.expects(:resolve_node).returns("host.domain.com")
        @handler.params(@request)[:node].should == "host.domain.com"
      end
    end
  end
end
