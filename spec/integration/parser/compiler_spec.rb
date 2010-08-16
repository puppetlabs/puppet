#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Compiler do
  before :each do
    @node = Puppet::Node.new "testnode"

    @scope_resource = stub 'scope_resource', :builtin? => true, :finish => nil, :ref => 'Class[main]'
    @scope = stub 'scope', :resource => @scope_resource, :source => mock("source")
  end

  after do
    Puppet.settings.clear
  end

  it "should be able to determine the configuration version from a local version control repository" do
    # This should always work, because we should always be
    # in the puppet repo when we run this.
    version = %x{git rev-parse HEAD}.chomp

    Puppet.settings[:config_version] = 'git rev-parse HEAD'

    @parser = Puppet::Parser::Parser.new "development"
    @compiler = Puppet::Parser::Compiler.new(@node)

    @compiler.catalog.version.should == version
  end

  describe "when resolving class references" do
    it "should favor local scope, even if there's an included class in topscope" do
      Puppet[:code] = <<-PP
        class experiment {
          class baz {
          }
          notify {"x" : require => Class[Baz] }
        }
        class baz {
        }
        include baz
        include experiment
        include experiment::baz
      PP

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

      notify_resource = catalog.resource( "Notify[x]" )

      notify_resource[:require].title.should == "Experiment::Baz"
    end

    it "should favor local scope, even if there's an unincluded class in topscope" do
      Puppet[:code] = <<-PP
        class experiment {
          class baz {
          }
          notify {"x" : require => Class[Baz] }
        }
        class baz {
        }
        include experiment
        include experiment::baz
      PP

      catalog = Puppet::Parser::Compiler.compile(Puppet::Node.new("mynode"))

      notify_resource = catalog.resource( "Notify[x]" )

      notify_resource[:require].title.should == "Experiment::Baz"
    end
  end
end
