require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "definitions" do

    it "should be able to create the definition" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notify {"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo do
          notify "foo"
        end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create a resource using definition" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notify {"foo": }
        }

        foo {"bar": }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo do
          notify "foo"
        end

        foo "bar"
      MANIFEST
      r.resources.map(&:name).should include "Foo/bar"

      r.should be_equivalent_to p
    end

    it "should be able to create a definition with arguments" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($name) {
          notify {"$name": }
        }

        foo {"bar": name => "asdf"}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo, :arguments => {:name => nil} do
          notify params[:name]
        end

        foo "bar", :name => "asdf"
      MANIFEST
      r.resources.map(&:name).should include "Notify/asdf"

      r.should be_equivalent_to p

    end

  end
end

