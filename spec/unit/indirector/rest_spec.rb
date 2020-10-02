require 'spec_helper'
require 'puppet/util/json'
require 'puppet/indirector'
require 'puppet/indirector/errors'
require 'puppet/indirector/rest'
require 'puppet/util/psych_support'

HTTP_ERROR_CODES = [300, 400, 500]

# Just one from each category since the code makes no real distinctions
shared_examples_for "a REST terminus method" do |terminus_method|

  describe "when handling the response" do
    let(:response) do
      mock_response(200, 'OK')
    end

    it "falls back to pson for future requests" do
      allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return("4.10.1")
      terminus.send(terminus_method, request)

      expect(Puppet[:preferred_serialization_format]).to eq("pson")
    end

    it "doesn't change the serialization format if the X-Puppet-Version header is missing" do
      allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return(nil)

      terminus.send(terminus_method, request)

      expect(Puppet[:preferred_serialization_format]).to eq("json")
    end

    it "doesn't change the serialization format if the server major version is 5" do
      allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return("5.0.3")

      terminus.send(terminus_method, request)

      expect(Puppet[:preferred_serialization_format]).to eq("json")
    end

    it "doesn't change the serialization format if the current format is already pson" do
      allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return("4.10.1")
      Puppet[:preferred_serialization_format] = "pson"
      terminus.send(terminus_method, request)

      expect(Puppet[:preferred_serialization_format]).to eq("pson")
    end

    it "logs a deprecation warning" do
      terminus.send(terminus_method, request)

      expect(@logs).to include(an_object_having_attributes(level: :warning, message: /Puppet::Indirector::Rest##{terminus_method} is deprecated. Use Puppet::HTTP::Client instead./))
    end

    it "omits the warning when deprecations are disabled" do
      Puppet[:disable_warnings] = 'deprecations'
      terminus.send(terminus_method, request)

      expect(@logs).to eq([])
    end
  end

  HTTP_ERROR_CODES.each do |code|
    describe "when the response code is #{code}" do
      let(:message) { 'error messaged!!!' }
      let(:body) do
        Puppet::Util::Json.dump({
          :issue_kind => 'server-error',
          :message    => message
        })
      end
      let(:response) { mock_response(code, body, 'application/json') }

      describe "when the response is plain text" do
        let(:response) { mock_response(code, message) }

        it "raises an http error with the body of the response when plain text" do

          expect {
            terminus.send(terminus_method, request)
          }.to raise_error(Net::HTTPError, "Error #{code} on SERVER: #{message}")
        end
      end

      it "raises an http error with the body's message field when json" do
        expect {
          terminus.send(terminus_method, request)
        }.to raise_error(Net::HTTPError, "Error #{code} on SERVER: #{message}")
      end

      it "does not attempt to deserialize the response into a model" do
        expect(model).not_to receive(:convert_from)

        expect {
          terminus.send(terminus_method, request)
        }.to raise_error(Net::HTTPError)
      end

      # I'm not sure what this means or if it's used
      it "if the body is empty raises an http error with the response header" do
        allow(response).to receive(:body).and_return("")
        allow(response).to receive(:message).and_return("fhqwhgads")

        expect {
          terminus.send(terminus_method, request)
        }.to raise_error(Net::HTTPError, "Error #{code} on SERVER: #{response.message}")
      end

      describe "and the body is compressed" do
        it "raises an http error with the decompressed body of the response" do
          compressed_body = Zlib::Deflate.deflate(body)

          compressed_response = mock_response(code, compressed_body, 'application/json', 'deflate')
          expect(connection).to receive(http_method).and_return(compressed_response)

          expect {
            terminus.send(terminus_method, request)
          }.to raise_error(Net::HTTPError, "Error #{code} on SERVER: #{message}")
        end
      end
    end
  end
end

shared_examples_for "a deserializing terminus method" do |terminus_method|
  describe "when the response has no content-type" do
    let(:response) { mock_response(200, "body", nil, nil) }
    it "raises an error" do
      expect {
        terminus.send(terminus_method, request)
      }.to raise_error(RuntimeError, "No content type in http response; cannot parse")
    end
  end

  it "doesn't catch errors in deserialization" do
    expect(model).to receive(:convert_from).and_raise(Puppet::Error, "Whoa there")

    expect { terminus.send(terminus_method, request) }.to raise_error(Puppet::Error, "Whoa there")
  end
end

describe Puppet::Indirector::REST do
  before :all do
    class Puppet::TestModel
      include Puppet::Util::PsychSupport
      extend Puppet::Indirector
      indirects :test_model
      attr_accessor :name, :data
      def initialize(name = "name", data = '')
        @name = name
        @data = data
      end

      def self.convert_from(format, string)
        new('', string)
      end

      def self.convert_from_multiple(format, string)
        string.split(',').collect { |s| convert_from(format, s) }
      end

      def to_data_hash
        { 'name' => @name, 'data' => @data }
      end

      def ==(other)
        other.is_a? Puppet::TestModel and other.name == name and other.data == data
      end
    end

    # The subclass must not be all caps even though the superclass is
    class Puppet::TestModel::Rest < Puppet::Indirector::REST
    end

    Puppet::TestModel.indirection.terminus_class = :rest
  end

  after :all do
    Puppet::TestModel.indirection.delete
    # Remove the class, unlinking it from the rest of the system.
    Puppet.send(:remove_const, :TestModel)
  end

  let(:terminus_class) { Puppet::TestModel::Rest }
  let(:terminus) { Puppet::TestModel.indirection.terminus(:rest) }
  let(:indirection) { Puppet::TestModel.indirection }
  let(:model) { Puppet::TestModel }
  let(:url_prefix) { "#{Puppet::Network::HTTP::MASTER_URL_PREFIX}/v3"}

  around(:each) do |example|
    Puppet.override(:current_environment => Puppet::Node::Environment.create(:production, [])) do
      example.run
    end
  end

  def mock_response(code, body, content_type='text/plain', encoding=nil)
    obj = double('http 200 ok', :code => code.to_s, :body => body)
    allow(obj).to receive(:[]).with('content-type').and_return(content_type)
    allow(obj).to receive(:[]).with('content-encoding').and_return(encoding)
    allow(obj).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return(Puppet.version)
    obj
  end

  def find_request(key, options={})
    Puppet::Indirector::Request.new(:test_model, :find, key, nil, options)
  end

  def head_request(key, options={})
    Puppet::Indirector::Request.new(:test_model, :head, key, nil, options)
  end

  def search_request(key, options={})
    Puppet::Indirector::Request.new(:test_model, :search, key, nil, options)
  end

  def delete_request(key, options={})
    Puppet::Indirector::Request.new(:test_model, :destroy, key, nil, options)
  end

  def save_request(key, instance, options={})
    Puppet::Indirector::Request.new(:test_model, :save, key, instance, options)
  end

  it "should have a method for specifying what setting a subclass should use to retrieve its server" do
    expect(terminus_class).to respond_to(:use_server_setting)
  end

  it "should use any specified setting to pick the server" do
    expect(terminus_class).to receive(:server_setting).and_return(:ca_server)
    Puppet[:ca_server] = "myserver"
    expect(terminus_class.server).to eq("myserver")
  end

  it "should default to :server for the server setting" do
    expect(terminus_class).to receive(:server_setting).and_return(nil)
    Puppet[:server] = "myserver"
    expect(terminus_class.server).to eq("myserver")
  end

  it "should have a method for specifying what setting a subclass should use to retrieve its port" do
    expect(terminus_class).to respond_to(:use_port_setting)
  end

  it "should use any specified setting to pick the port" do
    expect(terminus_class).to receive(:port_setting).and_return(:ca_port)
    Puppet[:ca_port] = "321"
    expect(terminus_class.port).to eq(321)
  end

  it "should default to :port for the port setting" do
    expect(terminus_class).to receive(:port_setting).and_return(nil)
    Puppet[:serverport] = "543"
    expect(terminus_class.port).to eq(543)
  end

  it "should use a failover-selected server if set" do
    expect(terminus_class).to receive(:server_setting).and_return(nil)
    Puppet.override(:server => "myserver") do
      expect(terminus_class.server).to eq("myserver")
    end
  end

  it "should use a failover-selected port if set" do
    expect(terminus_class).to receive(:port_setting).and_return(nil)
    Puppet.override(:serverport => 321) do
      expect(terminus_class.port).to eq(321)
    end
  end

  it "should use server_list for server when available" do
    expect(terminus_class).to receive(:server_setting).and_return(nil)
    Puppet[:server_list] = [["foo", "123"]]
    expect(terminus_class.server).to eq("foo")
  end

  it "should prefer failover-selected server from server list" do
    expect(terminus_class).to receive(:server_setting).and_return(nil)
    Puppet[:server_list] = [["foo", "123"],["bar", "321"]]
    Puppet.override(:server => "bar") do
      expect(terminus_class.server).to eq("bar")
    end
  end

  it "should use server_list for port when available" do
    expect(terminus_class).to receive(:port_setting).and_return(nil)
    Puppet[:server_list] = [["foo", "123"]]
    expect(terminus_class.port).to eq(123)
  end

  it "should prefer failover-selected port from server list" do
    expect(terminus_class).to receive(:port_setting).and_return(nil)
    Puppet[:server_list] = [["foo", "123"],["bar", "321"]]
    Puppet.override(:serverport => "321") do
      expect(terminus_class.port).to eq(321)
    end
  end

  it "should use an explicitly specified more-speciic server when failover is active" do
    expect(terminus_class).to receive(:server_setting).and_return(:ca_server)
    Puppet[:ca_server] = "myserver"
    Puppet.override(:server => "anotherserver") do
      expect(terminus_class.server).to eq("myserver")
    end
  end

  it "should use an explicitly specified more-specific port when failover is active" do
    expect(terminus_class).to receive(:port_setting).and_return(:ca_port)
    Puppet[:ca_port] = 321
    Puppet.override(:serverport => 543) do
      expect(terminus_class.port).to eq(321)
    end
  end

  it "should use a default port when a more-specific server is set" do
    expect(terminus_class).to receive(:server_setting).and_return(:ca_server)
    expect(terminus_class).to receive(:port_setting).and_return(:ca_port)
    Puppet[:ca_server] = "myserver"
    Puppet.override(:server => "anotherserver", :port => 666) do
      expect(terminus_class.port).to eq(8140)
    end
  end

  it 'should default to :puppet for the srv_service' do
    expect(Puppet::Indirector::REST.srv_service).to eq(:puppet)
  end

  it 'excludes yaml from the Accept header' do
    expect(model).to receive(:supported_formats).and_return([:json, :pson, :yaml, :binary])

    expect(terminus.headers['Accept']).to eq('application/json, text/pson, application/octet-stream')
  end

  it 'excludes b64_zlib_yaml from the Accept header' do
    expect(model).to receive(:supported_formats).and_return([:json, :pson, :b64_zlib_yaml])

    expect(terminus.headers['Accept']).to eq('application/json, text/pson')
  end

  it 'excludes dot from the Accept header' do
    expect(model).to receive(:supported_formats).and_return([:json, :dot])

    expect(terminus.headers['Accept']).to eq('application/json')
  end

  describe "when creating an HTTP client" do
    it "should use the class's server and port if the indirection request provides neither" do
      @request = double('request', :key => "foo", :server => nil, :port => nil)
      expect(terminus.class).to receive(:port).and_return(321)
      expect(terminus.class).to receive(:server).and_return("myserver")
      expect(Puppet::Network::HttpPool).to receive(:connection).with('myserver', 321, anything).and_return("myconn")
      expect(terminus.network(@request)).to eq("myconn")
    end

    it "should use the server from the indirection request if one is present" do
      @request = double('request', :key => "foo", :server => "myserver", :port => nil)
      allow(terminus.class).to receive(:port).and_return(321)
      expect(Puppet::Network::HttpPool).to receive(:connection).with('myserver', 321, anything).and_return("myconn")
      expect(terminus.network(@request)).to eq("myconn")
    end

    it "should use the port from the indirection request if one is present" do
      @request = double('request', :key => "foo", :server => nil, :port => 321)
      allow(terminus.class).to receive(:server).and_return("myserver")
      expect(Puppet::Network::HttpPool).to receive(:connection).with('myserver', 321, anything).and_return("myconn")
      expect(terminus.network(@request)).to eq("myconn")
    end
  end

  describe "#find" do
    let(:http_method) { :get }
    let(:response) { mock_response(200, 'body') }
    let(:connection) { double('mock http connection', :get => response, :verify_callback= => nil) }
    let(:request) { find_request('foo') }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it_behaves_like 'a REST terminus method', :find
    it_behaves_like 'a deserializing terminus method', :find

    describe "with a long set of parameters" do
      it "calls post on the connection with the query params in the body" do
        params = {}
        'aa'.upto('zz') do |s|
          params[s] = 'foo'
        end

        # The request special-cases this parameter, and it
        # won't be passed on to the server, so we remove it here
        # to avoid a failure.
        params.delete('ip')

        params["environment"] = "production"

        request = find_request('whoa', params)

        expect(connection).to receive(:post) do |_,req,_|
          expect(req.split("&").flatten).to match_array(params.map {|key,value| "#{key}=#{value}"})

          mock_response(200, 'body')
        end

        terminus.find(request)
      end
    end

    describe "with no parameters" do
      it "calls get on the connection" do
        request = find_request('foo bar')

        expect(connection).to receive(:get).with("#{url_prefix}/test_model/foo%20bar?environment=production&", anything).and_return(mock_response('200', 'response body'))

        expect(terminus.find(request)).to eq(model.new('foo bar', 'response body'))
      end
    end

    it "returns nil on 404" do
      response = mock_response('404', nil)

      expect(connection).to receive(:get).and_return(response)

      expect(terminus.find(request)).to eq(nil)
    end

    it 'raises no warning for a 404 (when not asked to do so)' do
      response = mock_response('404', 'this is the notfound you are looking for')
      expect(connection).to receive(:get).and_return(response)
      expect{terminus.find(request)}.to_not raise_error()
    end

    context 'when fail_on_404 is used in request' do
      it 'raises an error for a 404 when asked to do so' do
        request = find_request('foo', :fail_on_404 => true)
        response = mock_response('404', 'this is the notfound you are looking for')
        expect(connection).to receive(:get).and_return(response)

        expect do
          terminus.find(request)
        end.to raise_error(
          Puppet::Error,
          "Find #{url_prefix}/test_model/foo?environment=production&fail_on_404=true resulted in 404 with the message: this is the notfound you are looking for")
      end

      it 'truncates the URI when it is very long' do
        request = find_request('foo', :fail_on_404 => true, :long_param => ('A' * 100) + 'B')
        response = mock_response('404', 'this is the notfound you are looking for')
        expect(connection).to receive(:get).and_return(response)

        expect do
          terminus.find(request)
        end.to raise_error(
          Puppet::Error,
          /\/test_model\/foo.*\?environment=production&.*long_param=A+\.\.\..*resulted in 404 with the message/)
      end

      it 'does not truncate the URI when logging debug information' do
        Puppet.debug = true
        request = find_request('foo', :fail_on_404 => true, :long_param => ('A' * 100) + 'B')
        response = mock_response('404', 'this is the notfound you are looking for')
        expect(connection).to receive(:get).and_return(response)

        expect do
          terminus.find(request)
        end.to raise_error(
          Puppet::Error,
          /\/test_model\/foo.*\?environment=production&.*long_param=A+B.*resulted in 404 with the message/)
      end
    end

    it "asks the model to deserialize the response body and sets the name on the resulting object to the find key" do
      expect(connection).to receive(:get).and_return(response)

      expect(model).to receive(:convert_from).with(response['content-type'], response.body).and_return(
        model.new('overwritten', 'decoded body')
      )

      expect(terminus.find(request)).to eq(model.new('foo', 'decoded body'))
    end

    it "doesn't require the model to support name=" do
      class Puppet::TestModel2 < Puppet::TestModel
        undef_method :name=
      end

      expect(connection).to receive(:get).and_return(response)
      instance = Puppet::TestModel2.new('name', 'decoded body')

      expect(model).to receive(:convert_from).with(response['content-type'], response.body).and_return(instance)

      expect(terminus.find(request)).to eq(model.new('name', 'decoded body'))
    end

    it "provides an Accept header containing the list of supported mime types joined with commas" do
      expect(connection).to receive(:get).with(anything, hash_including("Accept" => "application/json, text/pson")).and_return(response)

      expect(terminus.model).to receive(:supported_formats).and_return([:json, :pson])
      terminus.find(request)
    end

    it "provides a version header with the current puppet version" do
      expect(connection).to receive(:get).with(anything, hash_including(Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version)).and_return(response)

      terminus.find(request)
    end

    it "adds an Accept-Encoding header" do
      expect(terminus).to receive(:add_accept_encoding).and_return({"accept-encoding" => "gzip"})

      expect(connection).to receive(:get).with(anything, hash_including("accept-encoding" => "gzip")).and_return(response)

      terminus.find(request)
    end

    it "uses only the mime-type from the content-type header when asking the model to deserialize" do
      response = mock_response('200', 'mydata', "text/plain; charset=utf-8")
      expect(connection).to receive(:get).and_return(response)

      expect(model).to receive(:convert_from).with("text/plain", "mydata").and_return("myobject")

      expect(terminus.find(request)).to eq("myobject")
    end

    it "decompresses the body before passing it to the model for deserialization" do
      uncompressed_body = "Why hello there"
      compressed_body = Zlib::Deflate.deflate(uncompressed_body)

      response = mock_response('200', compressed_body, 'text/plain', 'deflate')
      expect(connection).to receive(:get).and_return(response)

      expect(model).to receive(:convert_from).with("text/plain", uncompressed_body).and_return("myobject")

      expect(terminus.find(request)).to eq("myobject")
    end
  end

  describe "#head" do
    let(:http_method) { :head }
    let(:response) { mock_response(200, nil) }
    let(:connection) { double('mock http connection', :head => response, :verify_callback= => nil) }
    let(:request) { head_request('foo') }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it_behaves_like 'a REST terminus method', :head

    it "returns true if there was a successful http response" do
      expect(connection).to receive(:head).and_return(mock_response('200', nil))

      expect(terminus.head(request)).to eq(true)
    end

    it "returns false on a 404 response" do
      expect(connection).to receive(:head).and_return(mock_response('404', nil))

      expect(terminus.head(request)).to eq(false)
    end

    it "provides a version header with the current puppet version" do
      expect(connection).to receive(:head).with(anything, hash_including(Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version)).and_return(response)

      terminus.head(request)
    end
  end

  describe "#search" do
    let(:http_method) { :get }
    let(:response) { mock_response(200, 'data1,data2,data3') }
    let(:connection) { double('mock http connection', :get => response, :verify_callback= => nil) }
    let(:request) { search_request('foo') }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it_behaves_like 'a REST terminus method', :search
    it_behaves_like 'a deserializing terminus method', :search

    it "should call the GET http method on a network connection" do
      expect(connection).to receive(:get).with("#{url_prefix}/test_models/foo?environment=production&", hash_including('Accept' => anything)).and_return(mock_response(200, 'data3, data4'))

      terminus.search(request)
    end

    it "returns an empty list on 404" do
      response = mock_response('404', nil)

      expect(connection).to receive(:get).and_return(response)

      expect(terminus.search(request)).to eq([])
    end

    it "asks the model to deserialize the response body into multiple instances" do
      expect(terminus.search(request)).to eq([model.new('', 'data1'), model.new('', 'data2'), model.new('', 'data3')])
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      expect(connection).to receive(:get).with(anything, hash_including("Accept" => "application/json, text/pson")).and_return(mock_response(200, ''))

      expect(terminus.model).to receive(:supported_formats).and_return([:json, :pson])
      terminus.search(request)
    end

    it "provides a version header with the current puppet version" do
      expect(connection).to receive(:get).with(anything, hash_including(Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version)).and_return(mock_response(200, ''))

      terminus.search(request)
    end

    it "should return an empty array if serialization returns nil" do
      allow(model).to receive(:convert_from_multiple).and_return(nil)

      expect(terminus.search(request)).to eq([])
    end
  end

  describe "#destroy" do
    let(:http_method) { :delete }
    let(:response) { mock_response(200, 'body') }
    let(:connection) { double('mock http connection', :delete => response, :verify_callback= => nil) }
    let(:request) { delete_request('foo') }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it_behaves_like 'a REST terminus method', :destroy
    it_behaves_like 'a deserializing terminus method', :destroy

    it "should call the DELETE http method on a network connection" do
      expect(connection).to receive(:delete).with("#{url_prefix}/test_model/foo?environment=production&", hash_including('Accept' => anything)).and_return(response)

      terminus.destroy(request)
    end

    it "should fail if any options are provided, since DELETE apparently does not support query options" do
      request = delete_request('foo', :one => "two", :three => "four")

      expect { terminus.destroy(request) }.to raise_error(ArgumentError)
    end

    it "should deserialize and return the http response" do
      expect(connection).to receive(:delete).and_return(response)

      expect(terminus.destroy(request)).to eq(model.new('', 'body'))
    end

    it "returns nil on 404" do
      response = mock_response('404', nil)

      expect(connection).to receive(:delete).and_return(response)

      expect(terminus.destroy(request)).to eq(nil)
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      expect(connection).to receive(:delete).with(anything, hash_including("Accept" => "application/json, text/pson")).and_return(response)

      expect(terminus.model).to receive(:supported_formats).and_return([:json, :pson])
      terminus.destroy(request)
    end

    it "provides a version header with the current puppet version" do
      expect(connection).to receive(:delete).with(anything, hash_including(Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version)).and_return(response)

      terminus.destroy(request)
    end
  end

  describe "#save" do
    let(:http_method) { :put }
    let(:response) { mock_response(200, 'body') }
    let(:connection) { double('mock http connection', :put => response, :verify_callback= => nil) }
    let(:instance) { model.new('the thing', 'some contents') }
    let(:request) { save_request(instance.name, instance) }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it_behaves_like 'a REST terminus method', :save

    it "should call the PUT http method on a network connection" do
      expect(connection).to receive(:put).with("#{url_prefix}/test_model/the%20thing?environment=production&", anything, hash_including("Content-Type")).and_return(response)

      terminus.save(request)
    end

    it "should fail if any options are provided, since PUT apparently does not support query options" do
      request = save_request(instance.name, instance, :one => "two", :three => "four")

      expect { terminus.save(request) }.to raise_error(ArgumentError)
    end

    it "should serialize the instance using the default format and pass the result as the body of the request" do
      expect(instance).to receive(:render).and_return("serial_instance")
      expect(connection).to receive(:put).with(anything, "serial_instance", anything).and_return(response)

      terminus.save(request)
    end

    it "returns nil on 404" do
      response = mock_response('404', nil)

      expect(connection).to receive(:put).and_return(response)

      expect(terminus.save(request)).to eq(nil)
    end

    it "returns nil" do
      expect(connection).to receive(:put).and_return(response)

      expect(terminus.save(request)).to be_nil
    end

    it "should provide an Accept header containing the list of supported formats joined with commas" do
      expect(connection).to receive(:put).with(anything, anything, hash_including("Accept" => "application/json, text/pson")).and_return(response)

      expect(instance).to receive(:render).and_return('')
      expect(model).to receive(:supported_formats).and_return([:json, :pson])
      expect(instance).to receive(:mime).and_return("supported")

      terminus.save(request)
    end

    it "provides a version header with the current puppet version" do
      expect(connection).to receive(:put).with(anything, anything, hash_including(Puppet::Network::HTTP::HEADER_PUPPET_VERSION => Puppet.version)).and_return(response)

      terminus.save(request)
    end

    it "should provide a Content-Type header containing the mime-type of the sent object" do
      expect(instance).to receive(:mime).and_return("mime")
      expect(connection).to receive(:put).with(anything, anything, hash_including('Content-Type' => "mime")).and_return(response)

      terminus.save(request)
    end
  end

  describe '#handle_response' do
    # There are multiple request types to choose from, this may not be the one I want for this situation
    let(:response) { mock_response(200, 'body') }
    let(:connection) { double('mock http connection', :put => response, :verify_callback= => nil) }
    let(:instance) { model.new('the thing', 'some contents') }
    let(:request) { save_request(instance.name, instance) }

    before :each do
      allow(terminus).to receive(:network).and_return(connection)
    end

    it 'adds server_agent_version to the context if not already set' do
      expect(Puppet).to receive(:push_context).with(:server_agent_version => Puppet.version)
      terminus.handle_response(request, response)
    end

    it 'does not add server_agent_version to the context if it is already set' do
      Puppet.override(:server_agent_version => "5.3.4") do
        expect(Puppet).not_to receive(:push_context)
        terminus.handle_response(request, response)
      end
    end

    it 'downgrades to pson and emits a warning' do
      allow(response).to receive(:[]).with(Puppet::Network::HTTP::HEADER_PUPPET_VERSION).and_return('4.2.8')
      Puppet[:preferred_serialization_format] = 'other'

      expect(Puppet).to receive(:warning).with('Downgrading to PSON for future requests')

      terminus.handle_response(request, response)

      expect(Puppet[:preferred_serialization_format]).to eq('pson')
    end

    it 'preserves the set serialization format' do
      Puppet[:preferred_serialization_format] = 'other'

      expect(Puppet[:preferred_serialization_format]).to eq('other')

      terminus.handle_response(request, response)
    end
  end

  context 'dealing with SRV settings' do
    [
      :destroy,
      :find,
      :head,
      :save,
      :search
    ].each do |method|
      it "##{method} passes the SRV service, and fall-back server & port to the request's do_request method" do
        request = Puppet::Indirector::Request.new(:indirection, method, 'key', nil)
        stub_response = mock_response('200', 'body')

        expect(request).to receive(:do_request).with(terminus.class.srv_service, terminus.class.server, terminus.class.port).and_return(stub_response)

        terminus.send(method, request)
      end
    end
  end
end
