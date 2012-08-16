require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "nodes" do

    it "should be able to default node" do
      p = compile_to_catalog(<<-MANIFEST)
        node default {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "default" do
          notice "foo"
        end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create named node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "foonode" {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "foonode" do
          notice "foo"
        end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create node with regexp" do
      p = compile_to_catalog(<<-MANIFEST)
        node /^foo/ {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node /^foo/ do
          notice "foo"
        end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create node inheriting from another node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "base.example.com" {
          notice("base")
        }

        node "foonode" inherits "base.example.com" {
          notice "foonode"
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "base.example.com" do
          notice("base")
        end

        node "foonode", :inherits => "base.example.com" do
          notice "foonode"
        end
      MANIFEST

      r.should be_equivalent_to p
    end

  end
end

