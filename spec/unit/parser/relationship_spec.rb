#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/parser/relationship'

describe Puppet::Parser::Relationship do
  before do
    @source = Puppet::Resource.new(:mytype, "source")
    @target = Puppet::Resource.new(:mytype, "target")
    @extra_resource  = Puppet::Resource.new(:mytype, "extra")
    @extra_resource2 = Puppet::Resource.new(:mytype, "extra2")
    @dep = Puppet::Parser::Relationship.new(@source, @target, :relationship)
  end

  describe "when evaluating" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(@source)
      @catalog.add_resource(@target)
      @catalog.add_resource(@extra_resource)
      @catalog.add_resource(@extra_resource2)
    end

    it "should fail if the source resource cannot be found" do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @target
      expect { @dep.evaluate(@catalog) }.to raise_error(ArgumentError)
    end

    it "should fail if the target resource cannot be found" do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @source
      expect { @dep.evaluate(@catalog) }.to raise_error(ArgumentError)
    end

    it "should add the target as a 'before' value if the type is 'relationship'" do
      @dep.type = :relationship
      @dep.evaluate(@catalog)
      expect(@source[:before]).to be_include("Mytype[target]")
    end

    it "should add the target as a 'notify' value if the type is 'subscription'" do
      @dep.type = :subscription
      @dep.evaluate(@catalog)
      expect(@source[:notify]).to be_include("Mytype[target]")
    end

    it "should supplement rather than clobber existing relationship values" do
      @source[:before] = "File[/bar]"
      @dep.evaluate(@catalog)
      # this test did not work before. It was appending the resources
      # together as a string
      expect(@source[:before].class == Array).to be_truthy
      expect(@source[:before]).to be_include("Mytype[target]")
      expect(@source[:before]).to be_include("File[/bar]")
    end

    it "should supplement rather than clobber existing resource relationships" do
      @source[:before] = @extra_resource
      @dep.evaluate(@catalog)
      expect(@source[:before].class == Array).to be_truthy
      expect(@source[:before]).to be_include("Mytype[target]")
      expect(@source[:before]).to be_include(@extra_resource)
    end

    it "should supplement rather than clobber multiple existing resource relationships" do
      @source[:before] = [@extra_resource, @extra_resource2]
      @dep.evaluate(@catalog)
      expect(@source[:before].class == Array).to be_truthy
      expect(@source[:before]).to be_include("Mytype[target]")
      expect(@source[:before]).to be_include(@extra_resource)
      expect(@source[:before]).to be_include(@extra_resource2)
    end
  end
end
