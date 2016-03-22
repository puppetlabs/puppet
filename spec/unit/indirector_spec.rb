#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/defaults'
require 'puppet/indirector'

describe Puppet::Indirector, "when configuring routes" do
  before :each do
    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil
  end

  after :each do
    Puppet::Node.indirection.reset_terminus_class
    Puppet::Node.indirection.cache_class = nil
  end

  it "should configure routes as requested" do
    routes = {
      "node" => {
        "terminus" => "exec",
        "cache"    => "plain"
      }
    }

    Puppet::Indirector.configure_routes(routes)

    expect(Puppet::Node.indirection.terminus_class).to eq("exec")
    expect(Puppet::Node.indirection.cache_class).to    eq("plain")
  end

  it "should fail when given an invalid indirection" do
    routes = {
      "fake_indirection" => {
        "terminus" => "exec",
        "cache"    => "plain"
      }
    }

    expect { Puppet::Indirector.configure_routes(routes) }.to raise_error(/fake_indirection does not exist/)
  end

  it "should fail when given an invalid terminus" do
    routes = {
      "node" => {
        "terminus" => "fake_terminus",
        "cache"    => "plain"
      }
    }

    expect { Puppet::Indirector.configure_routes(routes) }.to raise_error(/Could not find terminus fake_terminus/)
  end

  it "should fail when given an invalid cache" do
    routes = {
      "node" => {
        "terminus" => "exec",
        "cache"    => "fake_cache"
      }
    }

    expect { Puppet::Indirector.configure_routes(routes) }.to raise_error(/Could not find terminus fake_cache/)
  end
end

describe Puppet::Indirector, " when available to a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
    end
  end

  it "should provide a way for the model to register an indirection under a name" do
    expect(@thingie).to respond_to(:indirects)
  end
end

describe Puppet::Indirector, "when registering an indirection" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector

      # override Class#name, since we're not naming this ephemeral class
      def self.name
        'Thingie'
      end

      attr_reader :name
      def initialize(name)
        @name = name
      end
    end
  end

  it "should require a name when registering a model" do
    expect {@thingie.send(:indirects) }.to raise_error(ArgumentError)
  end

  it "should create an indirection instance to manage each indirecting model" do
    @indirection = @thingie.indirects(:test)
    expect(@indirection).to be_instance_of(Puppet::Indirector::Indirection)
  end

  it "should not allow a model to register under multiple names" do
    # Keep track of the indirection instance so we can delete it on cleanup
    @indirection = @thingie.indirects :first
    expect { @thingie.indirects :second }.to raise_error(ArgumentError)
  end

  it "should make the indirection available via an accessor" do
    @indirection = @thingie.indirects :first
    expect(@thingie.indirection).to equal(@indirection)
  end

  it "should pass any provided options to the indirection during initialization" do
    klass = mock 'terminus class'
    Puppet::Indirector::Indirection.expects(:new).with(@thingie, :first, {:some => :options, :indirected_class => 'Thingie'})
    @indirection = @thingie.indirects :first, :some => :options
  end

  it "should extend the class to handle serialization" do
    @indirection = @thingie.indirects :first
    expect(@thingie).to respond_to(:convert_from)
  end

  after do
    @indirection.delete if @indirection
  end
end

describe Puppet::Indirector, "when redirecting a model" do
  before do
    @thingie = Class.new do
      extend Puppet::Indirector
      attr_reader :name
      def initialize(name)
        @name = name
      end
    end
    @indirection = @thingie.send(:indirects, :test)
  end

  it "should include the Envelope module in the model" do
    expect(@thingie.ancestors).to be_include(Puppet::Indirector::Envelope)
  end

  after do
    @indirection.delete
  end
end
