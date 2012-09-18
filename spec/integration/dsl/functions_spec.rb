require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "functions" do

    it "should be able to use a function from a node" do
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

      r.should be_equivalent_to_catalog p
    end

    it "should be able to use a function from a hostclass" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
          notice("foo")
        }

        include foo
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
          notice "foo"
        end

        use :foo
      MANIFEST

      r.should be_equivalent_to_catalog p
    end

    it "should be able to use a function from a definition" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notice("foo")
        }

        foo {"bar": }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo do
          notice "foo"
        end

        foo "bar"
      MANIFEST

      r.should be_equivalent_to_catalog p
    end

    it "should be able to use a function from top level scope" do
      p = compile_to_catalog(<<-MANIFEST)
          notice("foo")
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
          notice "foo"
      MANIFEST

      r.should be_equivalent_to_catalog p
    end

    it "should be able to pass parameters to the function" do
      p = compile_to_catalog(<<-MANIFEST)
          notice("foo", "bar", 3)
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
          notice "foo", "bar", 3
      MANIFEST

      r.should be_equivalent_to_catalog p
    end

  end
end

