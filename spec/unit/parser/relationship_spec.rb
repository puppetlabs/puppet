#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/parser/relationship'

describe Puppet::Parser::Relationship do
  before do
    @source = Puppet::Resource.new(:mytype, "source")
    @target = Puppet::Resource.new(:mytype, "target")
    @dep = Puppet::Parser::Relationship.new(@source, @target, :relationship)
  end

  describe "when evaluating" do
    before do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource(@source)
      @catalog.add_resource(@target)
    end

    it "should fail if the source resource cannot be found" do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @target
      lambda { @dep.evaluate(@catalog) }.should raise_error(ArgumentError)
    end

    it "should fail if the target resource cannot be found" do
      @catalog = Puppet::Resource::Catalog.new
      @catalog.add_resource @source
      lambda { @dep.evaluate(@catalog) }.should raise_error(ArgumentError)
    end

    it "should add the target as a 'before' value if the type is 'relationship'" do
      @dep.type = :relationship
      @dep.evaluate(@catalog)
      @source[:before].should be_include("Mytype[target]")
    end

    it "should add the target as a 'notify' value if the type is 'subscription'" do
      @dep.type = :subscription
      @dep.evaluate(@catalog)
      @source[:notify].should be_include("Mytype[target]")
    end

    it "should supplement rather than clobber existing relationship values" do
      @source[:before] = "File[/bar]"
      @dep.evaluate(@catalog)
      @source[:before].should be_include("Mytype[target]")
      @source[:before].should be_include("File[/bar]")
    end

    it "should use the collected retargets if the target is a Collector" do
      orig_target = @target
      @target = Puppet::Parser::Collector.new(stub("scope"), :file, "equery", "vquery", :virtual)
      @target.collected[:foo] = @target
      @dep.evaluate(@catalog)

      @source[:before].should be_include("Mytype[target]")
    end

    it "should use the collected resources if the source is a Collector" do
      orig_source = @source
      @source = Puppet::Parser::Collector.new(stub("scope"), :file, "equery", "vquery", :virtual)
      @source.collected[:foo] = @source
      @dep.evaluate(@catalog)

      orig_source[:before].should be_include("Mytype[target]")
    end
  end
end
