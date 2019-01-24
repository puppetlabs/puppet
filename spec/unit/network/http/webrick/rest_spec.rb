require 'spec_helper'
require 'puppet/network/http'
require 'webrick'
require 'puppet/network/http/webrick/rest'

describe Puppet::Network::HTTP::WEBrickREST do
  it "should include the Puppet::Network::HTTP::Handler module" do
    expect(Puppet::Network::HTTP::WEBrickREST.ancestors).to be_include(Puppet::Network::HTTP::Handler)
  end

  describe "when receiving a request" do
    before do
      @request     = double('webrick http request', :query => {},
                            :query_string => 'environment=production',
                            :peeraddr => %w{eh boo host ip},
                            :request_method => 'GET',
                            :client_cert => nil)
      @response    = double('webrick http response')
      @model_class = double('indirected model class')
      @webrick     = double('webrick http server', :mount => true, :[] => {})
      allow(Puppet::Indirector::Indirection).to receive(:model).with(:foo).and_return(@model_class)
      @handler = Puppet::Network::HTTP::WEBrickREST.new(@webrick)
    end

    it "should delegate its :service method to its :process method" do
      expect(@handler).to receive(:process).with(@request, @response).and_return("stuff")
      expect(@handler.service(@request, @response)).to eq("stuff")
    end

    describe "#headers" do
      let(:fake_request) { {"Foo" => "bar", "BAZ" => "bam" } }

      it "should iterate over the request object using #each" do
        expect(fake_request).to receive(:each)
        @handler.headers(fake_request)
      end

      it "should return a hash with downcased header names" do
        result = @handler.headers(fake_request)
        expect(result).to eq(fake_request.inject({}) { |m,(k,v)| m[k.downcase] = v; m })
      end
    end

    describe "when using the Handler interface" do
      it "should use the request method as the http method" do
        expect(@request).to receive(:request_method).and_return("FOO")
        expect(@handler.http_method(@request)).to eq("FOO")
      end

      it "should return the request path as the path" do
        expect(@request).to receive(:path).and_return("/foo/bar")
        expect(@handler.path(@request)).to eq("/foo/bar")
      end

      it "should return the request body as the body" do
        allow(@request).to receive(:request_method).and_return("POST")
        expect(@request).to receive(:body).and_return("my body")
        expect(@handler.body(@request)).to eq("my body")
      end

      it "should set the response's 'content-type' header when setting the content type" do
        expect(@response).to receive(:[]=).with("content-type", "text/html")
        @handler.set_content_type(@response, "text/html")
      end

      it "should set the status and body on the response when setting the response for a successful query" do
        expect(@response).to receive(:status=).with(200)
        expect(@response).to receive(:body=).with("mybody")

        @handler.set_response(@response, "mybody", 200)
      end

      it "serves a file" do
        stat = double('stat', :size => 100)
        @file = double('file', :stat => stat, :path => "/tmp/path")
        allow(@file).to receive(:is_a?).with(File).and_return(true)

        expect(@response).to receive(:[]=).with('content-length', 100)
        expect(@response).to receive(:status=).with(200)
        expect(@response).to receive(:body=).with(@file)

        @handler.set_response(@response, @file, 200)
      end

      it "should set the status and message on the response when setting the response for a failed query" do
        expect(@response).to receive(:status=).with(400)
        expect(@response).to receive(:body=).with("mybody")

        @handler.set_response(@response, "mybody", 400)
      end
    end

    describe "and determining the request parameters" do
      def query_of(options)
        request = Puppet::Indirector::Request.new(:myind, :find, "my key", nil, options)
        WEBrick::HTTPUtils.parse_query(request.query_string.sub(/^\?/, ''))
      end

      def a_request_querying(query_data)
        expect(@request).to receive(:query).and_return(query_of(query_data))
        @request
      end

      def certificate_with_subject(subj)
        cert = OpenSSL::X509::Certificate.new
        cert.subject = OpenSSL::X509::Name.parse(subj)
        cert
      end

      it "has no parameters when there is no query string" do
        only_server_side_information = [:authenticated, :ip, :node]
        allow(@request).to receive(:query).and_return(nil)

        result = @handler.params(@request)

        expect(result.keys.sort).to eq(only_server_side_information)
      end

      it "should prefer duplicate params from the body over the query string" do
        allow(@request).to receive(:request_method).and_return("PUT")
        allow(@request).to receive(:query).and_return(WEBrick::HTTPUtils.parse_query("foo=bar&environment=posted_env"))
        expect(@handler.params(@request)[:environment]).to eq("posted_env")
      end

      it "should include the HTTP request parameters, with the keys as symbols" do
        request = a_request_querying("foo" => "baz", "bar" => "xyzzy")
        result = @handler.params(request)

        expect(result[:foo]).to eq("baz")
        expect(result[:bar]).to eq("xyzzy")
      end

      it "should handle parameters with no value" do
        request = a_request_querying('foo' => "")

        result = @handler.params(request)

        expect(result[:foo]).to eq("")
      end

      it "should convert the string 'true' to the boolean" do
        request = a_request_querying('foo' => "true")

        result = @handler.params(request)

        expect(result[:foo]).to eq(true)
      end

      it "should convert the string 'false' to the boolean" do
        request = a_request_querying('foo' => "false")

        result = @handler.params(request)

        expect(result[:foo]).to eq(false)
      end

      it "should reconstruct arrays" do
        request = a_request_querying('foo' => ["a", "b", "c"])

        result = @handler.params(request)

        expect(result[:foo]).to eq(["a", "b", "c"])
      end

      it "should convert values inside arrays into primitive types" do
        request = a_request_querying('foo' => ["true", "false", "1", "1.2"])

        result = @handler.params(request)

        expect(result[:foo]).to eq([true, false, 1, 1.2])
      end

      it "should treat YAML-load values that are YAML-encoded as any other String" do
        request = a_request_querying('foo' => YAML.dump(%w{one two}))
        expect(@handler.params(request)[:foo]).to eq("---\n- one\n- two\n")
      end

      it "should not allow clients to set the node via the request parameters" do
        request = a_request_querying("node" => "foo")
        allow(@handler).to receive(:resolve_node)

        expect(@handler.params(request)[:node]).to be_nil
      end

      it "should not allow clients to set the IP via the request parameters" do
        request = a_request_querying("ip" => "foo")

        expect(@handler.params(request)[:ip]).not_to eq("foo")
      end

      it "should pass the client's ip address to model find" do
        allow(@request).to receive(:peeraddr).and_return(%w{noidea dunno hostname ipaddress})
        expect(@handler.params(@request)[:ip]).to eq("ipaddress")
      end

      it "should set 'authenticated' to true if a certificate is present" do
        cert = double('cert', :subject => [%w{CN host.domain.com}])
        allow(@request).to receive(:client_cert).and_return(cert)
        expect(@handler.params(@request)[:authenticated]).to be_truthy
      end

      it "should set 'authenticated' to false if no certificate is present" do
        allow(@request).to receive(:client_cert).and_return(nil)
        expect(@handler.params(@request)[:authenticated]).to be_falsey
      end

      it "should pass the client's certificate name to model method if a certificate is present" do
        allow(@request).to receive(:client_cert).and_return(certificate_with_subject("/CN=host.domain.com"))

        expect(@handler.params(@request)[:node]).to eq("host.domain.com")
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        allow(@request).to receive(:client_cert).and_return(nil)

        expect(@handler).to receive(:resolve_node).and_return(:resolved_node)

        expect(@handler.params(@request)[:node]).to eq(:resolved_node)
      end

      it "should resolve the node name with an ip address look-up if CN parsing fails" do
        allow(@request).to receive(:client_cert).and_return(certificate_with_subject("/C=company"))

        expect(@handler).to receive(:resolve_node).and_return(:resolved_node)

        expect(@handler.params(@request)[:node]).to eq(:resolved_node)
      end
    end
  end
end
