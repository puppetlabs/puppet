#! /usr/bin/env ruby
require 'spec_helper'
require 'matchers/json'
require 'puppet/indirector/request'

describe Puppet::Indirector::Request do
  include JSONMatchers

  describe "when initializing" do
    it "should always convert the indirection name to a symbol" do
      expect(Puppet::Indirector::Request.new("ind", :method, "mykey", nil).indirection_name).to eq(:ind)
    end

    it "should use provided value as the key if it is a string" do
      expect(Puppet::Indirector::Request.new(:ind, :method, "mykey", nil).key).to eq("mykey")
    end

    it "should use provided value as the key if it is a symbol" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :mykey, nil).key).to eq(:mykey)
    end

    it "should use the name of the provided instance as its key if an instance is provided as the key instead of a string" do
      instance = mock 'instance', :name => "mykey"
      request = Puppet::Indirector::Request.new(:ind, :method, nil, instance)
      expect(request.key).to eq("mykey")
      expect(request.instance).to equal(instance)
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
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, nil).options).to eq({})
    end

    it "should default to a nil node" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil).node).to be_nil
    end

    it "should set its node attribute if provided in the options" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :node => "foo.com").node).to eq("foo.com")
    end

    it "should default to a nil ip" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil).ip).to be_nil
    end

    it "should set its ip attribute if provided in the options" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ip => "192.168.0.1").ip).to eq("192.168.0.1")
    end

    it "should default to being unauthenticated" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil)).not_to be_authenticated
    end

    it "should set be marked authenticated if configured in the options" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :authenticated => "eh")).to be_authenticated
    end

    it "should keep its options as a hash even if a node is specified" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :node => "eh").options).to be_instance_of(Hash)
    end

    it "should keep its options as a hash even if another option is specified" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :foo => "bar").options).to be_instance_of(Hash)
    end

    it "should treat options other than :ip, :node, and :authenticated as options rather than attributes" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :server => "bar").options[:server]).to eq("bar")
    end

    it "should normalize options to use symbols as keys" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, "foo" => "bar").options[:foo]).to eq("bar")
    end

    describe "and the request key is a URI" do
      let(:file) { File.expand_path("/my/file with spaces") }
      let(:an_environment) { Puppet::Node::Environment.create(:an_environment, []) }
      let(:env_loaders) { Puppet::Environments::Static.new(an_environment) }

      around(:each) do |example|
        Puppet.override({ :environments => env_loaders }, "Static environment loader for specs") do
          example.run
        end
      end

      describe "and the URI is a 'file' URI" do
        before do
          @request = Puppet::Indirector::Request.new(:ind, :method, "#{URI.unescape(Puppet::Util.path_to_uri(file).to_s)}", nil)
        end

        it "should set the request key to the unescaped full file path" do
          expect(@request.key).to eq(file)
        end

        it "should not set the protocol" do
          expect(@request.protocol).to be_nil
        end

        it "should not set the port" do
          expect(@request.port).to be_nil
        end

        it "should not set the server" do
          expect(@request.server).to be_nil
        end
      end

      it "should set the protocol to the URI scheme" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/", nil).protocol).to eq("http")
      end

      it "should set the server if a server is provided" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/", nil).server).to eq("host")
      end

      it "should set the server and port if both are provided" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host:543/", nil).port).to eq(543)
      end

      it "should default to the masterport if the URI scheme is 'puppet'" do
        Puppet[:masterport] = "321"
        expect(Puppet::Indirector::Request.new(:ind, :method, "puppet://host/", nil).port).to eq(321)
      end

      it "should use the provided port if the URI scheme is not 'puppet'" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/", nil).port).to eq(80)
      end

      it "should set the request key to the unescaped path from the URI" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff with spaces", nil).key).to eq("stuff with spaces")
      end

      it "should set the :uri attribute to the full URI" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http:///a/path/stu ff", nil).uri).to eq('http:///a/path/stu ff')
      end

      it "should not parse relative URI" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "foo/bar", nil).uri).to be_nil
      end

      it "should not parse opaque URI" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "mailto:joe", nil).uri).to be_nil
      end
    end

    it "should allow indication that it should not read a cached instance" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ignore_cache => true)).to be_ignore_cache
    end

    it "should default to not ignoring the cache" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil)).not_to be_ignore_cache
    end

    it "should allow indication that it should not not read an instance from the terminus" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil, :ignore_terminus => true)).to be_ignore_terminus
    end

    it "should default to not ignoring the terminus" do
      expect(Puppet::Indirector::Request.new(:ind, :method, :key, nil)).not_to be_ignore_terminus
    end
  end

  it "should look use the Indirection class to return the appropriate indirection" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    expect(request.indirection).to equal(ind)
  end

  it "should use its indirection to look up the appropriate model" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    ind.expects(:model).returns "mymodel"

    expect(request.model).to eq("mymodel")
  end

  it "should fail intelligently when asked to find a model but the indirection cannot be found" do
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns nil
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    expect { request.model }.to raise_error(ArgumentError)
  end

  it "should have a method for determining if the request is plural or singular" do
    expect(Puppet::Indirector::Request.new(:myind, :method, :key, nil)).to respond_to(:plural?)
  end

  it "should be considered plural if the method is 'search'" do
    expect(Puppet::Indirector::Request.new(:myind, :search, :key, nil)).to be_plural
  end

  it "should not be considered plural if the method is not 'search'" do
    expect(Puppet::Indirector::Request.new(:myind, :find, :key, nil)).not_to be_plural
  end

  it "should use its uri, if it has one, as its description" do
    Puppet.override({
      :environments => Puppet::Environments::Static.new(
        Puppet::Node::Environment.create(:baz, [])
    )},
      "Static loader for spec") do
      expect(Puppet::Indirector::Request.new(:myind, :find, "foo://bar/baz", nil).description).to eq("foo://bar/baz")
      end
  end

  it "should use its indirection name and key, if it has no uri, as its description" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "key", nil).description).to eq("/myind/key")
  end

  it "should be able to return the URI-escaped key" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil).escaped_key).to eq(URI.escape("my key"))
  end

  it "should set its environment to an environment instance when a string is specified as its environment" do
    env = Puppet::Node::Environment.create(:foo, [])

    Puppet.override(:environments => Puppet::Environments::Static.new(env)) do
      expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :environment => "foo").environment).to eq(env)
    end
  end

  it "should use any passed in environment instances as its environment" do
    env = Puppet::Node::Environment.create(:foo, [])

    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :environment => env).environment).to equal(env)
  end

  it "should use the current environment when none is provided" do
    configured = Puppet::Node::Environment.create(:foo, [])

    Puppet[:environment] = "foo"

    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil).environment).to eq(Puppet.lookup(:current_environment))
  end

  it "should support converting its options to a hash" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil )).to respond_to(:to_hash)
  end

  it "should include all of its attributes when its options are converted to a hash" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :node => 'foo').to_hash[:node]).to eq('foo')
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

      expect(request.query_string).to eq("")
    end

    it "should return an empty query string if the options are empty" do
      request = a_request_with_options({})

      expect(request.query_string).to eq("")
    end

    it "should include all options in the query string, separated by '&'" do
      request = a_request_with_options(:one => "two", :three => "four")

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["two"],
        "three" => ["four"]
      })
    end

    it "should ignore nil options" do
      request = a_request_with_options(:one => "two", :three => nil)

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["two"]
      })
    end

    it "should convert 'true' option values into strings" do
      request = a_request_with_options(:one => true)

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["true"]
      })
    end

    it "should convert 'false' option values into strings" do
      request = a_request_with_options(:one => false)

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["false"]
      })
    end

    it "should convert to a string all option values that are integers" do
      request = a_request_with_options(:one => 50)

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["50"]
      })
    end

    it "should convert to a string all option values that are floating point numbers" do
      request = a_request_with_options(:one => 1.2)

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["1.2"]
      })
    end

    it "should CGI-escape all option values that are strings" do
      request = a_request_with_options(:one => "one two")

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["one two"]
      })
    end

    it "should convert an array of values into multiple entries for the same key" do
      request = a_request_with_options(:one => %w{one two})

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["one", "two"]
      })
    end

    it "should stringify simple data types inside an array" do
      request = a_request_with_options(:one => ['one', nil])

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["one"]
      })
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

      expect(the_parsed_query_string_from(request)).to eq({
        "one" => ["sym bol"]
      })
    end

    it "should fail if options other than booleans or strings are provided" do
      request = a_request_with_options(:one => { :one => :two })

      expect { request.query_string }.to raise_error(ArgumentError)
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
          expect(got.server).to eq('puppet.example.com')
          expect(got.port).to   eq('90210')
          'Block return value'
        end
        expect(count).to eq(1)

        expect(rval).to eq('Block return value')
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
          expect(got.server).to eq('puppet.example.com')
          expect(got.port).to   eq('90210')
          'Block return value'
        end
        expect(count).to eq(1)

        expect(rval).to eq('Block return value')
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
            expect(got.server).to eq('_x-puppet._tcp.example.com')
            expect(got.port).to eq(7205)

            @block_return
          end
          expect(count).to eq(1)

          expect(rval).to eq(@block_return)
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

          expect(second_pass.server).to eq('puppet')
          expect(second_pass.port).to   eq(8140)
          expect(count).to eq(2)

          expect(rval).to eq(@block_return)
        end
      end
    end
  end

  describe "#remote?" do
    def request(options = {})
      Puppet::Indirector::Request.new('node', 'find', 'localhost', nil, options)
    end

    it "should not be unless node or ip is set" do
      expect(request).not_to be_remote
    end

    it "should be remote if node is set" do
      expect(request(:node => 'example.com')).to be_remote
    end

    it "should be remote if ip is set" do
      expect(request(:ip => '127.0.0.1')).to be_remote
    end

    it "should be remote if node and ip are set" do
      expect(request(:node => 'example.com', :ip => '127.0.0.1')).to be_remote
    end
  end
end
