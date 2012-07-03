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

  describe "params" do

    it "should be able to set variable" do
      p = compile_to_catalog(<<-MANIFEST)
        node default {
          $asdf = "foo"
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "default" do
          params[:asdf] = "foo"
        end
      MANIFEST

      r.should == p
    end

    it "should be able to read a variable" do
      p = compile_to_catalog(<<-MANIFEST)
        node default {
          $asdf = "foo"

          notice($asdf)
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "default" do
          params[:asdf] = "foo"

          notice params[:asdf]
        end
      MANIFEST

      r.should == p
    end

    it "should be able to read params for a resource" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($msg) {
          notice($msg)
        }

        node default {
          foo {"foo": msg => "asdf"}
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo, :arguments => {:msg => nil} do
          notice params[:msg]
        end

        node "default" do
          foo :foo, :msg => "asdf"
        end
      MANIFEST

      r.should == p
    end

  end
end

