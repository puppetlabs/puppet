require 'puppet'
require 'spec_helper'
require 'puppet_spec/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Catalog
include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "resources" do

    it "should be able to define resource" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)

      MANIFEST

      r.should == p
    end

    it "should be able to define resource with parameters" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($msg) {
          notice($msg)
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
      MANIFEST

      r.should == p
    end

    it "should be able to use defined resource" do
      p = compile_to_catalog(<<-MANIFEST)
      define foo() {
        notice("foo")
      }

      foo {"foo": }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
      MANIFEST

      r.should == p
    end

    it "should be able to use defined resource in a node" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notice("foo")
        }

        node default {
          foo {"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
      MANIFEST

      r.should == p
    end

    it "should be able to use defined resource in a class" do
      p = compile_to_catalog(<<-MANIFEST)

      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
      MANIFEST

      r.should == p
    end


  end
end

