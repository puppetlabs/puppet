#!/usr/bin/env rspec
require 'spec_helper'
require 'matchers/json'
require 'puppet/indirector/request'

describe Puppet::Indirector::Request do
  describe "when initializing" do
    it "should require an indirection name, a key, and a method" do
      lambda { Puppet::Indirector::Request.new }.should raise_error(ArgumentError)
    end

    it "should always convert the indirection name to a symbol" do
      Puppet::Indirector::Request.new("ind", :method, "mykey").indirection_name.should == :ind
    end

    it "should use provided value as the key if it is a string" do
      Puppet::Indirector::Request.new(:ind, :method, "mykey").key.should == "mykey"
    end

    it "should use provided value as the key if it is a symbol" do
      Puppet::Indirector::Request.new(:ind, :method, :mykey).key.should == :mykey
    end

    it "should use the name of the provided instance as its key if an instance is provided as the key instead of a string" do
      instance = mock 'instance', :name => "mykey"
      request = Puppet::Indirector::Request.new(:ind, :method, instance)
      request.key.should == "mykey"
      request.instance.should equal(instance)
    end

    it "should support options specified as a hash" do
      lambda { Puppet::Indirector::Request.new(:ind, :method, :key, :one => :two) }.should_not raise_error(ArgumentError)
    end

    it "should support nil options" do
      lambda { Puppet::Indirector::Request.new(:ind, :method, :key, nil) }.should_not raise_error(ArgumentError)
    end

    it "should support unspecified options" do
      lambda { Puppet::Indirector::Request.new(:ind, :method, :key) }.should_not raise_error(ArgumentError)
    end

    it "should use an empty options hash if nil was provided" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).options.should == {}
    end

    it "should default to a nil node" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).node.should be_nil
    end

    it "should set its node attribute if provided in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :node => "foo.com").node.should == "foo.com"
    end

    it "should default to a nil ip" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).ip.should be_nil
    end

    it "should set its ip attribute if provided in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :ip => "192.168.0.1").ip.should == "192.168.0.1"
    end

    it "should default to being unauthenticated" do
      Puppet::Indirector::Request.new(:ind, :method, :key, nil).should_not be_authenticated
    end

    it "should set be marked authenticated if configured in the options" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :authenticated => "eh").should be_authenticated
    end

    it "should keep its options as a hash even if a node is specified" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :node => "eh").options.should be_instance_of(Hash)
    end

    it "should keep its options as a hash even if another option is specified" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :foo => "bar").options.should be_instance_of(Hash)
    end

    it "should treat options other than :ip, :node, and :authenticated as options rather than attributes" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :server => "bar").options[:server].should == "bar"
    end

    it "should normalize options to use symbols as keys" do
      Puppet::Indirector::Request.new(:ind, :method, :key, "foo" => "bar").options[:foo].should == "bar"
    end

    describe "and the request key is a URI" do
      let(:file) { File.expand_path("/my/file with spaces") }

      describe "and the URI is a 'file' URI" do
        before do
          @request = Puppet::Indirector::Request.new(:ind, :method, "#{URI.unescape(Puppet::Util.path_to_uri(file).to_s)}")
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
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff").protocol.should == "http"
      end

      it "should set the server if a server is provided" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff").server.should == "host"
      end

      it "should set the server and port if both are provided" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host:543/stuff").port.should == 543
      end

      it "should default to the masterport if the URI scheme is 'puppet'" do
        Puppet.settings.expects(:value).with(:masterport).returns "321"
        Puppet::Indirector::Request.new(:ind, :method, "puppet://host/stuff").port.should == 321
      end

      it "should use the provided port if the URI scheme is not 'puppet'" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/stuff").port.should == 80
      end

      it "should set the request key to the unescaped key part path from the URI" do
        Puppet::Indirector::Request.new(:ind, :method, "http://host/environment/terminus/stuff with spaces").key.should == "stuff with spaces"
      end

      it "should set the :uri attribute to the full URI" do
        Puppet::Indirector::Request.new(:ind, :method, "http:///stu ff").uri.should == 'http:///stu ff'
      end

      it "should not parse relative URI" do
        Puppet::Indirector::Request.new(:ind, :method, "foo/bar").uri.should be_nil
      end

      it "should not parse opaque URI" do
        Puppet::Indirector::Request.new(:ind, :method, "mailto:joe").uri.should be_nil
      end
    end

    it "should allow indication that it should not read a cached instance" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :ignore_cache => true).should be_ignore_cache
    end

    it "should default to not ignoring the cache" do
      Puppet::Indirector::Request.new(:ind, :method, :key).should_not be_ignore_cache
    end

    it "should allow indication that it should not not read an instance from the terminus" do
      Puppet::Indirector::Request.new(:ind, :method, :key, :ignore_terminus => true).should be_ignore_terminus
    end

    it "should default to not ignoring the terminus" do
      Puppet::Indirector::Request.new(:ind, :method, :key).should_not be_ignore_terminus
    end
  end

  it "should look use the Indirection class to return the appropriate indirection" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key)

    request.indirection.should equal(ind)
  end

  it "should use its indirection to look up the appropriate model" do
    ind = mock 'indirection'
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns ind
    request = Puppet::Indirector::Request.new(:myind, :method, :key)

    ind.expects(:model).returns "mymodel"

    request.model.should == "mymodel"
  end

  it "should fail intelligently when asked to find a model but the indirection cannot be found" do
    Puppet::Indirector::Indirection.expects(:instance).with(:myind).returns nil
    request = Puppet::Indirector::Request.new(:myind, :method, :key)

    lambda { request.model }.should raise_error(ArgumentError)
  end

  it "should have a method for determining if the request is plural or singular" do
    Puppet::Indirector::Request.new(:myind, :method, :key).should respond_to(:plural?)
  end

  it "should be considered plural if the method is 'search'" do
    Puppet::Indirector::Request.new(:myind, :search, :key).should be_plural
  end

  it "should not be considered plural if the method is not 'search'" do
    Puppet::Indirector::Request.new(:myind, :find, :key).should_not be_plural
  end

  it "should use its uri, if it has one, as its string representation" do
    Puppet::Indirector::Request.new(:myind, :find, "foo://bar/baz").to_s.should == "foo://bar/baz"
  end

  it "should use its indirection name and key, if it has no uri, as its string representation" do
    Puppet::Indirector::Request.new(:myind, :find, "key") == "/myind/key"
  end

  it "should be able to return the URI-escaped key" do
    Puppet::Indirector::Request.new(:myind, :find, "my key").escaped_key.should == URI.escape("my key")
  end

  it "should have an environment accessor" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", :environment => "foo").should respond_to(:environment)
  end

  it "should set its environment to an environment instance when a string is specified as its environment" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", :environment => "foo").environment.should == Puppet::Node::Environment.new("foo")
  end

  it "should use any passed in environment instances as its environment" do
    env = Puppet::Node::Environment.new("foo")
    Puppet::Indirector::Request.new(:myind, :find, "my key", :environment => env).environment.should equal(env)
  end

  it "should use the default environment when none is provided" do
    Puppet::Indirector::Request.new(:myind, :find, "my key" ).environment.should equal(Puppet::Node::Environment.new)
  end

  it "should support converting its options to a hash" do
    Puppet::Indirector::Request.new(:myind, :find, "my key" ).should respond_to(:to_hash)
  end

  it "should include all of its attributes when its options are converted to a hash" do
    Puppet::Indirector::Request.new(:myind, :find, "my key", :node => 'foo').to_hash[:node].should == 'foo'
  end

  describe "when building a query string from its options" do
    before do
      @request = Puppet::Indirector::Request.new(:myind, :find, "my key")
    end

    it "should return an empty query string if there are no options" do
      @request.stubs(:options).returns nil
      @request.query_string.should == ""
    end

    it "should return an empty query string if the options are empty" do
      @request.stubs(:options).returns({})
      @request.query_string.should == ""
    end

    it "should prefix the query string with '?'" do
      @request.stubs(:options).returns(:one => "two")
      @request.query_string.should =~ /^\?/
    end

    it "should include all options in the query string, separated by '&'" do
      @request.stubs(:options).returns(:one => "two", :three => "four")
      @request.query_string.sub(/^\?/, '').split("&").sort.should == %w{one=two three=four}.sort
    end

    it "should ignore nil options" do
      @request.stubs(:options).returns(:one => "two", :three => nil)
      @request.query_string.should_not be_include("three")
    end

    it "should convert 'true' option values into strings" do
      @request.stubs(:options).returns(:one => true)
      @request.query_string.should == "?one=true"
    end

    it "should convert 'false' option values into strings" do
      @request.stubs(:options).returns(:one => false)
      @request.query_string.should == "?one=false"
    end

    it "should convert to a string all option values that are integers" do
      @request.stubs(:options).returns(:one => 50)
      @request.query_string.should == "?one=50"
    end

    it "should convert to a string all option values that are floating point numbers" do
      @request.stubs(:options).returns(:one => 1.2)
      @request.query_string.should == "?one=1.2"
    end

    it "should CGI-escape all option values that are strings" do
      escaping = CGI.escape("one two")
      @request.stubs(:options).returns(:one => "one two")
      @request.query_string.should == "?one=#{escaping}"
    end

    it "should YAML-dump and CGI-escape arrays" do
      escaping = CGI.escape(YAML.dump(%w{one two}))
      @request.stubs(:options).returns(:one => %w{one two})
      @request.query_string.should == "?one=#{escaping}"
    end

    it "should convert to a string and CGI-escape all option values that are symbols" do
      escaping = CGI.escape("sym bol")
      @request.stubs(:options).returns(:one => :"sym bol")
      @request.query_string.should == "?one=#{escaping}"
    end

    it "should fail if options other than booleans or strings are provided" do
      @request.stubs(:options).returns(:one => {:one => :two})
      lambda { @request.query_string }.should raise_error(ArgumentError)
    end
  end
end
