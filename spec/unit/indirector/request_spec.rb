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
      instance = double('instance', :name => "mykey")
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
          @request = Puppet::Indirector::Request.new(:ind, :method, "#{Puppet::Util.uri_unescape(Puppet::Util.path_to_uri(file).to_s)}", nil)
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

      it "should default to the serverport if the URI scheme is 'puppet'" do
        Puppet[:serverport] = "321"
        expect(Puppet::Indirector::Request.new(:ind, :method, "puppet://host/", nil).port).to eq(321)
      end

      it "should use the provided port if the URI scheme is not 'puppet'" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/", nil).port).to eq(80)
      end

      it "should set the request key to the unescaped path from the URI" do
        expect(Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff with spaces", nil).key).to eq("stuff with spaces")
      end

      it "should set the request key to the unescaped path from the URI, in UTF-8 encoding" do
        path = "\u4e07"
        uri = "http://host/#{path}"
        request = Puppet::Indirector::Request.new(:ind, :method, uri, nil)

        expect(request.key).to eq(path)
        expect(request.key.encoding).to eq(Encoding::UTF_8)
      end

      it "should set the request key properly given a UTF-8 URI" do
        # different UTF-8 widths
        # 1-byte A
        # 2-byte ۿ - http://www.fileformat.info/info/unicode/char/06ff/index.htm - 0xDB 0xBF / 219 191
        # 3-byte ᚠ - http://www.fileformat.info/info/unicode/char/16A0/index.htm - 0xE1 0x9A 0xA0 / 225 154 160
        # 4-byte <U+070E> - http://www.fileformat.info/info/unicode/char/2070E/index.htm - 0xF0 0xA0 0x9C 0x8E / 240 160 156 142
        mixed_utf8 = "A\u06FF\u16A0\u{2070E}" # Aۿᚠ<U+070E>

        key = "a/path/stu ff/#{mixed_utf8}"
        req = Puppet::Indirector::Request.new(:ind, :method, "http:///#{key}", nil)
        expect(req.key).to eq(key)
        expect(req.key.encoding).to eq(Encoding::UTF_8)
        expect(req.uri).to eq("http:///#{key}")
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
    ind = double('indirection')
    expect(Puppet::Indirector::Indirection).to receive(:instance).with(:myind).and_return(ind)
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    expect(request.indirection).to equal(ind)
  end

  it "should use its indirection to look up the appropriate model" do
    ind = double('indirection')
    expect(Puppet::Indirector::Indirection).to receive(:instance).with(:myind).and_return(ind)
    request = Puppet::Indirector::Request.new(:myind, :method, :key, nil)

    expect(ind).to receive(:model).and_return("mymodel")

    expect(request.model).to eq("mymodel")
  end

  it "should fail intelligently when asked to find a model but the indirection cannot be found" do
    expect(Puppet::Indirector::Indirection).to receive(:instance).with(:myind).and_return(nil)
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
    Puppet.override(
      { :environments => Puppet::Environments::Static.new(Puppet::Node::Environment.create(:baz, [])) },
      "Static loader for spec"
    ) do
      expect(Puppet::Indirector::Request.new(:myind, :find, "foo://bar/baz", nil).description).to eq("foo://bar/baz")
    end
  end

  it "should use its indirection name and key, if it has no uri, as its description" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "key", nil).description).to eq("/myind/key")
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
    Puppet[:environment] = "foo"

    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil).environment).to eq(Puppet.lookup(:current_environment))
  end

  it "should support converting its options to a hash" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil )).to respond_to(:to_hash)
  end

  it "should include all of its attributes when its options are converted to a hash" do
    expect(Puppet::Indirector::Request.new(:myind, :find, "my key", nil, :node => 'foo').to_hash[:node]).to eq('foo')
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
