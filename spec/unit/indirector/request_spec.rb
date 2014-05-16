#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/json'
require 'puppet/indirector/request'
require 'puppet/util/pson'

describe Puppet::Indirector::Request do
  include JSONMatchers

  describe "when registering the document type" do
    it "should register its document type with JSON" do
      PSON.registered_document_types["IndirectorRequest"].should equal(Puppet::Indirector::Request)
    end
  end

  describe "when initializing" do
    it "should always convert the indirection name to a symbol" do
      Puppet::Indirector::Request.new("ind", :method, "mykey", nil).indirection_name.should == :ind
    end

    it "should use provided value as the key if it is a string" do
      Puppet::Indirector::Request.new(:ind, :method, "mykey", nil).key.should == "mykey"
    end

    it "should use provided value as the key if it is a symbol" do
      Puppet::Indirector::Request.new(:ind, :method, :mykey, nil).key.should == :mykey
    end

    it "should use the name of the provided instance as its key if an instance is provided as the key instead of a string" do
      instance = mock 'instance', :name => "mykey"
      request = Puppet::Indirector::Request.new(:ind, :method, nil, instance)
      request.key.should == "mykey"
      request.instance.should equal(instance)
    end

    it "should support options specified as a hash" do
      expect { Puppet::Indirector::Request.new(:ind, :method, :key, nil, :one => :two) }.to_not raise_error
    end

    it "should support nil options" do
      expect { Puppet::Indirector::Request.new(:ind, :method, :key, nil, nil) }.to_not raise_error
    end

    it "should support unspecified options" do
      expect { Puppet::Indirector::Request.new(:ind, :method, :key, nil) }.to_not raise_error
    end

    it "should use an empty options hash if nil was provided" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, nil).options.should == {}
    end

    it "should default to a nil node" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).node.should be_nil
    end

    it "should set its node attribute if provided in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :node => "foo.com").node.should == "foo.com"
    end

    it "should default to a nil ip" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).ip.should be_nil
    end

    it "should set its ip attribute if provided in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ip => "192.168.0.1").ip.should == "192.168.0.1"
    end

    it "should default to being unauthenticated" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).should_not be_authenticated
    end

    it "should set be marked authenticated if configured in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :authenticated => "eh").should be_authenticated
    end

    it "should keep its options as a hash even if a node is specified" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :node => "eh").options.should be_instance_of(Hash)
    end

    it "should keep its options as a hash even if another option is specified" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :foo => "bar").options.should be_instance_of(Hash)
    end

    it "should treat options other than :ip, :node, and :authenticated as options rather than attributes" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :server => "bar").options[:server].should == "bar"
    end

    it "should normalize options to use symbols as keys" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, "foo" => "bar").options[:foo].should == "bar"
    end

    describe "and the request key is a URI" do
      let(:file) { File.expand_path("/my/file with spaces") }

      describe "and the URI is a 'file' URI" do
        before do
          @request = Puppet::Indirector::Request.new(:ind, :method, "#{URI.unescape(Puppet::Util.path_to_uri(file).to_s)}", nil)
        end

        it "should set the request key to the unescaped full file path" do
          @request.key.should == file
        end

        it "should not set the protocol" do
          @request.protocol.should be_nil
        end

        it "should not set the port" do
          @request.port.should be_nil
        end

        it "should not set the server" do
          @request.server.should be_nil
        end
      end

      it "should set the protocol to the URI scheme" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff", nil).protocol.should == "http"
      end

      it "should set the server if a server is provided" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff", nil).server.should == "host"
      end

      it "should set the server and port if both are provided" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host:543/stuff", nil).port.should == 543
      end

      it "should default to the masterport if the URI scheme is 'puppet'" do
        Puppet[:masterport] = "321"
        Puppet::Indirector::Request.new(:ind, :method, "puppet://host/stuff", nil).port.should == 321
      end

      it "should use the provided port if the URI scheme is not 'puppet'" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff", nil).port.should == 80
      end

      it "should set the request key to the unescaped key part path from the URI" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/environment/terminus/stuff with spaces", nil).key.should == "stuff with spaces"
      end

      it "should set the :uri attribute to the full URI" do
        Puppet::Indirector::Request.new(:ind, :method, "http:///stu ff", nil).uri.should == 'http:///stu ff'
      end

      it "should not parse relative URI" do
        Puppet::Indirector::Request.new(:ind, :method, "foo/bar", nil).uri.should be_nil
      end

      it "should not parse opaque URI" do
        Puppet::Indirector::Request.new(:ind, :method, "mailto:joe", nil).uri.should be_nil
      end
    end

    it "should allow indication that it should not read a cached instance" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ignore_cache => true).should be_ignore_cache
    end

    it "should default to not ignoring the cache" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).should_not be_ignore_cache
    end

    it "should allow indication that it should not not read an instance from the terminus" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ignore_terminus => true).should be_ignore_terminus
    end

    it "should default to not ignoring the terminus" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).should_not be_ignore_terminus
    end
  end

  it "should look use the Indirection class to return the appropriate indirection" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    request.indirection.should equal(ind)
  end

  it "should use its indirection to look up the appropriate model" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    ind.expects(:model).returns "mymodel"

    request.model.should == "mymodel"
  end

  it "should fail intelligently when asked to find a model but the indirection cannot be found" do
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns nil
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    expect { request.model }.to raise_error(ArgumentError)
  end

  it "should have a method for determining if the request is plural or singular" do
    Puppet::Indirector::Request.new(:myind, :method, :key, nil).should respond_to(:plural?)
  end

  it "should be considered plural if the method is 'search'" do
    Puppet::Indirector::Request.new(:myind, :search, :key, nil).should be_plural
  end

  it "should not be considered plural if the method is not 'search'" do
    Puppet::Indirector::Request.new(:myind, :find, :key, nil).should_not be_plural
  end

  it "should use its uri, if it has one, as its string representation" do
    Puppet::Indirector::Request.new(:myind, :find, "foo://bar/baz", nil).to_s.should == "foo://bar/baz"
  end

  it "should use its indirection name and key, if it has no uri, as its string representation" do
    Puppet::Indirector::Request.new(:myind, :find, "key", nil) == "/myind/key"
  end

  it "should be able to return the URI-escaped key" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", nil).escaped_key.should == URI.escape("my key")
  end

  it "should set its environment to an environment instance when a string is specified as its environment" do
    env = Puppet::Node::Environment.create(:foo, [])

    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :environment => "foo").environment.should == env
    end
  end

  it "should use any passed in environment instances as its environment" do
    env = Puppet::Node::Environment.create(:foo, [])

    Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :environment => env).environment.should equal(env)
  end

  it "should use the current environment when none is provided" do
    configured = Puppet::Node::Environment.create(:foo, [])

    Puppet[:environment] = "foo"

    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil).environment).to eq(Puppet.lookup(:current_environment))
  end

  it "should support converting its options to a hash" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", nil ).should respond_to(:to_hash)
  end

  it "should include all of its attributes when its options are converted to a hash" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :node => 'foo').to_hash[:node].should == 'foo'
  end

  describe "when building a query string from its options" do
    def a_request_with_options(options)
      Puppet::Indirector::Request.new(:myind, :find, "my key", nil, options)
    end

    def the_parsed_query_string_from(request)
      CGI.parse(request.query_string.sub(/^\?/, ''))
    end

    it "should return an empty query string if there are no options" do
      request = a_request_with_options(nil)

      request.query_string.should == ""
    end

    it "should return an empty query string if the options are empty" do
      request = a_request_with_options({})

      request.query_string.should == ""
    end

    it "should prefix the query string with '?'" do
      request = a_request_with_options(:one => "two")

      request.query_string.should =~ /^\?/
    end

    it "should include all options in the query string, separated by '&'" do
      request = a_request_with_options(:one => "two", :three => "four")

      the_parsed_query_string_from(request).should == {
        "one" => ["two"],
        "three" => ["four"]
      }
    end

    it "should ignore nil options" do
      request = a_request_with_options(:one => "two", :three => nil)

      the_parsed_query_string_from(request).should == {
        "one" => ["two"]
      }
    end

    it "should convert 'true' option values into strings" do
      request = a_request_with_options(:one => true)

      the_parsed_query_string_from(request).should == {
        "one" => ["true"]
      }
    end

    it "should convert 'false' option values into strings" do
      request = a_request_with_options(:one => false)

      the_parsed_query_string_from(request).should == {
        "one" => ["false"]
      }
    end

    it "should convert to a string all option values that are integers" do
      request = a_request_with_options(:one => 50)

      the_parsed_query_string_from(request).should == {
        "one" => ["50"]
      }
    end

    it "should convert to a string all option values that are floating point numbers" do
      request = a_request_with_options(:one => 1.2)

      the_parsed_query_string_from(request).should == {
        "one" => ["1.2"]
      }
    end

    it "should CGI-escape all option values that are strings" do
      request = a_request_with_options(:one => "one two")

      the_parsed_query_string_from(request).should == {
        "one" => ["one two"]
      }
    end

    it "should convert an array of values into multiple entries for the same key" do
      request = a_request_with_options(:one => %w{one two})

      the_parsed_query_string_from(request).should == {
        "one" => ["one", "two"]
      }
    end

    it "should convert an array of values into a single yaml entry when in legacy mode" do
      Puppet[:legacy_query_parameter_serialization] = true
      request = a_request_with_options(:one => %w{one two})

      the_parsed_query_string_from(request).should == {
          "one" => ["--- \n  - one\n  - two"]
      }
    end

    it "should stringify simple data types inside an array" do
      request = a_request_with_options(:one => ['one', nil])

      the_parsed_query_string_from(request).should == {
        "one" => ["one"]
      }
    end

    it "should error if an array contains another array" do
      request = a_request_with_options(:one => ['one', ["not allowed"]])

      expect { request.query_string }.to raise_error(ArgumentError)
    end

    it "should error if an array contains illegal data" do
      request = a_request_with_options(:one => ['one', { :not => "allowed" }])

      expect { request.query_string }.to raise_error(ArgumentError)
    end

    it "should convert to a string and CGI-escape all option values that are symbols" do
      request = a_request_with_options(:one => :"sym bol")

      the_parsed_query_string_from(request).should == {
        "one" => ["sym bol"]
      }
    end

    it "should fail if options other than booleans or strings are provided" do
      request = a_request_with_options(:one => { :one => :two })

      expect { request.query_string }.to raise_error(ArgumentError)
    end
  end

  describe "when converting to json" do
    before do
      @request = Puppet::Indirector::Request.new(:facts, :find, "foo", nil)
    end

    it "should produce a hash with the document_type set to 'request'" do
      @request.should set_json_document_type_to("IndirectorRequest")
    end

    it "should set the 'key'" do
      @request.should set_json_attribute("key").to("foo")
    end

    it "should include an attribute for its indirection name" do
      @request.should set_json_attribute("type").to("facts")
    end

    it "should include a 'method' attribute set to its method" do
      @request.should set_json_attribute("method").to("find")
    end

    it "should add all attributes under the 'attributes' attribute" do
      @request.ip = "127.0.0.1"
      @request.should set_json_attribute("attributes", "ip").to("127.0.0.1")
    end

    it "should add all options under the 'attributes' attribute" do
      @request.options["opt"] = "value"
      PSON.parse(@request.to_pson)["data"]['attributes']['opt'].should == "value"
    end

    it "should include the instance if provided" do
      facts = Puppet::Node::Facts.new("foo")
      @request.instance = facts
      PSON.parse(@request.to_pson)["data"]['instance'].should be_instance_of(Hash)
    end
  end

  describe "when converting from json" do
    before do
      @request = Puppet::Indirector::Request.new(:facts, :find, "foo", nil)
      @klass = Puppet::Indirector::Request
      @format = Puppet::Network::FormatHandler.format('pson')
    end

    def from_json(json)
      @format.intern(Puppet::Indirector::Request, json)
    end

    it "should set the 'key'" do
      from_json(@request.to_pson).key.should == "foo"
    end

    it "should fail if no key is provided" do
      json = PSON.parse(@request.to_pson)
      json['data'].delete("key")
      expect { from_json(json.to_pson) }.to raise_error(ArgumentError)
    end

    it "should set its indirector name" do
      from_json(@request.to_pson).indirection_name.should == :facts
    end

    it "should fail if no type is provided" do
      json = PSON.parse(@request.to_pson)
      json['data'].delete("type")
      expect { from_json(json.to_pson) }.to raise_error(ArgumentError)
    end

    it "should set its method" do
      from_json(@request.to_pson).method.should == "find"
    end

    it "should fail if no method is provided" do
      json = PSON.parse(@request.to_pson)
      json['data'].delete("method")
      expect { from_json(json.to_pson) }.to raise_error(ArgumentError)
    end

    it "should initialize with all attributes and options" do
      @request.ip = "127.0.0.1"
      @request.options["opt"] = "value"
      result = from_json(@request.to_pson)
      result.options[:opt].should == "value"
      result.ip.should == "127.0.0.1"
    end

    it "should set its instance as an instance if one is provided" do
      facts = Puppet::Node::Facts.new("foo")
      @request.instance = facts
      result = from_json(@request.to_pson)
      result.instance.should be_instance_of(Puppet::Node::Facts)
    end
  end

  context '#do_request' do
    before :each do
      @request = Puppet::Indirector::Request.new(:myind, :find, "my key", nil)
    end

    context 'when not using SRV records' do
      before :each do
        Puppet.settings[:use_srv_records] = false
      end

      it "yields the request with the default server and port when no server or port were specified on the original request" do
        count = 0
        rval = @request.do_request(:puppet, 'puppet.example.com', '90210') do |got|
          count += 1
          got.server.should == 'puppet.example.com'
          got.port.should   == '90210'
          'Block return value'
        end
        count.should == 1

        rval.should == 'Block return value'
      end
    end

    context 'when using SRV records' do
      before :each do
        Puppet.settings[:use_srv_records] = true
        Puppet.settings[:srv_domain]      = 'example.com'
      end

      it "yields the request with the original server and port unmodified" do
        @request.server = 'puppet.example.com'
        @request.port   = '90210'

        count = 0
        rval = @request.do_request do |got|
          count += 1
          got.server.should == 'puppet.example.com'
          got.port.should   == '90210'
          'Block return value'
        end
        count.should == 1

        rval.should == 'Block return value'
      end

      context "when SRV returns servers" do
        before :each do
          @dns_mock = mock('dns')
          Resolv::DNS.expects(:new).returns(@dns_mock)

          @port = 7205
          @host = '_x-puppet._tcp.example.com'
          @srv_records = [Resolv::DNS::Resource::IN::SRV.new(0, 0, @port, @host)]

          @dns_mock.expects(:getresources).
            with("_x-puppet._tcp.#{Puppet.settings[:srv_domain]}", Resolv::DNS::Resource::IN::SRV).
            returns(@srv_records)
        end

        it "yields a request using the server and port from the SRV record" do
          count = 0
          rval = @request.do_request do |got|
            count += 1
            got.server.should == '_x-puppet._tcp.example.com'
            got.port.should == 7205

            @block_return
          end
          count.should == 1

          rval.should == @block_return
        end

        it "should fall back to the default server when the block raises a SystemCallError" do
          count = 0
          second_pass = nil

          rval = @request.do_request(:puppet, 'puppet', 8140) do |got|
            count += 1

            if got.server == '_x-puppet._tcp.example.com' then
              raise SystemCallError, "example failure"
            else
              second_pass = got
            end

            @block_return
          end

          second_pass.server.should == 'puppet'
          second_pass.port.should   == 8140
          count.should == 2

          rval.should == @block_return
        end
      end
    end
  end

  describe "#remote?" do
    def request(options = {})
      Puppet::Indirector::Request.new('node', 'find', 'localhost', nil, options)
    end

    it "should not be unless node or ip is set" do
      request.should_not be_remote
    end

    it "should be remote if node is set" do
      request(:node => 'example.com').should be_remote
    end

    it "should be remote if ip is set" do
      request(:ip => '127.0.0.1').should be_remote
    end

    it "should be remote if node and ip are set" do
      request(:node => 'example.com', :ip => '127.0.0.1').should be_remote
    end
  end
end
