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

    it "should be able to create default node" do
      p = compile_to_catalog(<<-MANIFEST)
        node default {
          notify{"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "default" do
          notify "foo"
        end
      MANIFEST
      r.resources.map(&:name).should include "Notify/foo"

      r.should be_equivalent_to p
    end

    it "should be able to create named node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "foonode" {
          notify{"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "foonode" do
          notify "foo"
        end
      MANIFEST
      r.resources.map(&:name).should include "Notify/foo"

      r.should be_equivalent_to p
    end

    it "should be able to create node with regexp" do
      p = compile_to_catalog(<<-MANIFEST)
        node /^foo/ {
          notify{"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node /^foo/ do
          notify "foo"
        end
      MANIFEST
      r.resources.map(&:name).should include "Notify/foo"

      r.should be_equivalent_to p
    end

    it "should be able to create node inheriting from another node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "base.example.com" {
          notify {"base": }
        }

        node "foonode" inherits "base.example.com" {
          notify {"foonode": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "base.example.com" do
          notify "base"
        end

        node "foonode", :inherits => "base.example.com" do
          notify "foonode"
        end
      MANIFEST

      r.resources.map(&:name).tap do |names|
        %w[base foonode].each do |node_name|
          names.should include "Notify/#{node_name}"
        end
      end

      r.should be_equivalent_to p
    end

  end
end

