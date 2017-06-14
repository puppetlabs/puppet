#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http/rack' if Puppet.features.rack?
require 'puppet/network/http/rack/rest'

describe "Puppet::Network::HTTP::RackREST", :if => Puppet.features.rack? do
  it "should include the Puppet::Network::HTTP::Handler module" do
    expect(Puppet::Network::HTTP::RackREST.ancestors).to be_include(Puppet::Network::HTTP::Handler)
  end

  describe "when serving a request" do
    before :all do
      @model_class = stub('indirected model class')
      Puppet::Indirector::Indirection.stubs(:model).with(:foo).returns(@model_class)
    end

    before :each do
      @response = Rack::Response.new
      @handler = Puppet::Network::HTTP::RackREST.new(:handler => :foo)
    end

    def mk_req(uri, opts = {})
      env = Rack::MockRequest.env_for(uri, opts)
      Rack::Request.new(env)
    end

    let(:minimal_certificate) do
      key = OpenSSL::PKey::RSA.new(512)
      signer = Puppet::SSL::CertificateSigner.new
      cert = OpenSSL::X509::Certificate.new
      cert.version = 2
      cert.serial = 0
      cert.not_before = Time.now
      cert.not_after = Time.now + 3600
      cert.public_key = key
      cert.subject = OpenSSL::X509::Name.parse("/CN=testing")
      signer.sign(cert, key)
      cert
    end

    describe "#headers" do
      it "should return the headers (parsed from env with prefix 'HTTP_')" do
        req = mk_req('/', {'HTTP_Accept' => 'myaccept',
                           'HTTP_X_Custom_Header' => 'mycustom',
                           'NOT_HTTP_foo' => 'not an http header'})
        expect(@handler.headers(req)).to eq({"accept" => 'myaccept',
                                         "x-custom-header" => 'mycustom',
                                         "content-type" => nil })
      end
    end

    describe "and using the HTTP Handler interface" do
      it "should return the CONTENT_TYPE parameter as the content type header" do
        req = mk_req('/', 'CONTENT_TYPE' => 'mycontent')
        expect(@handler.headers(req)['content-type']).to eq("mycontent")
      end

      it "should use the REQUEST_METHOD as the http method" do
        req = mk_req('/', :method => 'MYMETHOD')
        expect(@handler.http_method(req)).to eq("MYMETHOD")
      end

      it "should return the request path as the path" do
        req = mk_req('/foo/bar')
        expect(@handler.path(req)).to eq("/foo/bar")
      end

      it "should return the unescaped path for an escaped request path" do
        unescaped_path = '/foo/bar baz'
        escaped_path = URI.escape(unescaped_path)
        req = mk_req(escaped_path)
        expect(@handler.path(req)).to eq(unescaped_path)
      end

      it "should return the request body as the body" do
        req = mk_req('/foo/bar', :input => 'mybody')
        expect(@handler.body(req)).to eq("mybody")
      end

      it "should return the an Puppet::SSL::Certificate instance as the client_cert" do
        req = mk_req('/foo/bar', 'SSL_CLIENT_CERT' => minimal_certificate.to_pem)
        expect(@handler.client_cert(req).content.to_pem).to eq(minimal_certificate.to_pem)
      end

      it "returns nil when SSL_CLIENT_CERT is empty" do
        req = mk_req('/foo/bar', 'SSL_CLIENT_CERT' => '')

        expect(@handler.client_cert(req)).to be_nil
      end

      it "should set the response's content-type header when setting the content type" do
        @header = mock 'header'
        @response.expects(:header).returns @header
        @header.expects(:[]=).with('Content-Type', "mytype")

        @handler.set_content_type(@response, "mytype")
      end

      it "should set the status and write the body when setting the response for a request" do
        @response.expects(:status=).with(400)
        @response.expects(:write).with("mybody")

        @handler.set_response(@response, "mybody", 400)
      end

      describe "when result is a File" do
        before :each do
          stat = stub 'stat', :size => 100
          @file = stub 'file', :stat => stat, :path => "/tmp/path"
          @file.stubs(:is_a?).with(File).returns(true)
        end

        it "should set the Content-Length header as a string" do
          @response.expects(:[]=).with("Content-Length", '100')

          @handler.set_response(@response, @file, 200)
        end

        it "should return a RackFile adapter as body" do
          @response.expects(:body=).with { |val| val.is_a?(Puppet::Network::HTTP::RackREST::RackFile) }

          @handler.set_response(@response, @file, 200)
        end
      end

      it "should ensure the body has been read on success" do
        req = mk_req('/production/report/foo', :method => 'PUT')
        req.body.expects(:read).at_least_once

        Puppet::Transaction::Report.stubs(:save)

        @handler.process(req, @response)
      end

      it "should ensure the body has been partially read on failure" do
        req = mk_req('/production/report/foo')
        req.body.expects(:read).with(1)

        @handler.stubs(:headers).raises(StandardError)

        @handler.process(req, @response)
      end
    end

    describe "and determining the request parameters" do
      it "should include the HTTP request parameters, with the keys as symbols" do
        req = mk_req('/?foo=baz&bar=xyzzy')
        result = @handler.params(req)
        expect(result[:foo]).to eq("baz")
        expect(result[:bar]).to eq("xyzzy")
      end

      it "should return multi-values params as an array of the values" do
        req = mk_req('/?foo=baz&foo=xyzzy')
        result = @handler.params(req)
        expect(result[:foo]).to eq(["baz", "xyzzy"])
      end

      it "should return parameters from the POST body" do
        req = mk_req("/", :method => 'POST', :input => 'foo=baz&bar=xyzzy')
        result = @handler.params(req)
        expect(result[:foo]).to eq("baz")
        expect(result[:bar]).to eq("xyzzy")
      end

      it "should not return multi-valued params in a POST body as an array of values" do
        req = mk_req("/", :method => 'POST', :input => 'foo=baz&foo=xyzzy')
        result = @handler.params(req)
        expect(result[:foo]).to be_one_of("baz", "xyzzy")
      end

      it "should CGI-decode the HTTP parameters" do
        encoding = CGI.escape("foo bar")
        req = mk_req("/?foo=#{encoding}")
        result = @handler.params(req)
        expect(result[:foo]).to eq("foo bar")
      end

      it "should convert the string 'true' to the boolean" do
        req = mk_req("/?foo=true")
        result = @handler.params(req)
        expect(result[:foo]).to be_truthy
      end

      it "should convert the string 'false' to the boolean" do
        req = mk_req("/?foo=false")
        result = @handler.params(req)
        expect(result[:foo]).to be_falsey
      end

      it "should convert integer arguments to Integers" do
        req = mk_req("/?foo=15")
        result = @handler.params(req)
        expect(result[:foo]).to eq(15)
      end

      it "should convert floating point arguments to Floats" do
        req = mk_req("/?foo=1.5")
        result = @handler.params(req)
        expect(result[:foo]).to eq(1.5)
      end

      it "should treat YAML encoded parameters like it was any string" do
        escaping = CGI.escape(YAML.dump(%w{one two}))
        req = mk_req("/?foo=#{escaping}")
        expect(@handler.params(req)[:foo]).to eq("---\n- one\n- two\n")
      end

      it "should not allow the client to set the node via the query string" do
        req = mk_req("/?node=foo")
        expect(@handler.params(req)[:node]).to be_nil
      end

      it "should not allow the client to set the IP address via the query string" do
        req = mk_req("/?ip=foo")
        expect(@handler.params(req)[:ip]).to be_nil
      end

      it "should pass the client's ip address to model find" do
        req = mk_req("/", 'REMOTE_ADDR' => 'ipaddress')
        expect(@handler.params(req)[:ip]).to eq("ipaddress")
      end

      it "should set 'authenticated' to false if no certificate is present" do
        req = mk_req('/')
        expect(@handler.params(req)[:authenticated]).to be_falsey
      end
    end

    describe "with pre-validated certificates" do
      it "should retrieve the hostname by finding the CN given in :ssl_client_header, in the format returned by Apache (RFC2253)" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => "O=Foo\\, Inc,CN=host.domain.com")
        expect(@handler.params(req)[:node]).to eq("host.domain.com")
      end

      it "should retrieve the hostname by finding the CN given in :ssl_client_header, in the format returned by nginx" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => "/CN=host.domain.com")
        expect(@handler.params(req)[:node]).to eq("host.domain.com")
      end

      it "should retrieve the hostname by finding the CN given in :ssl_client_header, ignoring other fields" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => 'ST=Denial,CN=host.domain.com,O=Domain\\, Inc.')
        expect(@handler.params(req)[:node]).to eq("host.domain.com")
      end

      it "should use the :ssl_client_header to determine the parameter for checking whether the host certificate is valid" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => "SUCCESS", "certheader" => "CN=host.domain.com")
        expect(@handler.params(req)[:authenticated]).to be_truthy
      end

      it "should consider the host unauthenticated if the validity parameter does not contain 'SUCCESS'" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => "whatever", "certheader" => "CN=host.domain.com")
        expect(@handler.params(req)[:authenticated]).to be_falsey
      end

      it "should consider the host unauthenticated if no certificate information is present" do
        Puppet[:ssl_client_header] = "certheader"
        Puppet[:ssl_client_verify_header] = "myheader"
        req = mk_req('/', "myheader" => nil, "certheader" => "CN=host.domain.com")
        expect(@handler.params(req)[:authenticated]).to be_falsey
      end

      it "should resolve the node name with an ip address look-up if no certificate is present" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => nil)
        @handler.expects(:resolve_node).returns("host.domain.com")
        expect(@handler.params(req)[:node]).to eq("host.domain.com")
      end

      it "should resolve the node name with an ip address look-up if a certificate without a CN is present" do
        Puppet[:ssl_client_header] = "myheader"
        req = mk_req('/', "myheader" => "O=no CN")
        @handler.expects(:resolve_node).returns("host.domain.com")
        expect(@handler.params(req)[:node]).to eq("host.domain.com")
      end

      it "should not allow authentication via the verify header if there is no CN available" do
        Puppet[:ssl_client_header] = "dn_header"
        Puppet[:ssl_client_verify_header] = "verify_header"
        req = mk_req('/', "dn_header" => "O=no CN", "verify_header" => 'SUCCESS')

        @handler.expects(:resolve_node).returns("host.domain.com")

        expect(@handler.params(req)[:authenticated]).to be_falsey
      end
    end
  end
end

describe Puppet::Network::HTTP::RackREST::RackFile do
  before(:each) do
    stat = stub 'stat', :size => 100
    @file = stub 'file', :stat => stat, :path => "/tmp/path"
    @rackfile = Puppet::Network::HTTP::RackREST::RackFile.new(@file)
  end

  it "should have an each method" do
    expect(@rackfile).to be_respond_to(:each)
  end

  it "should yield file chunks by chunks" do
    @file.expects(:read).times(3).with(8192).returns("1", "2", nil)
    i = 1
    @rackfile.each do |chunk|
      expect(chunk.to_i).to eq(i)
      i += 1
    end
  end

  it "should have a close method" do
    expect(@rackfile).to be_respond_to(:close)
  end

  it "should delegate close to File close" do
    @file.expects(:close)
    @rackfile.close
  end
end
