require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
    @catalog = compile_to_catalog(<<-MANIFEST)
                 Notify { message => "foo" }
               MANIFEST
  end

  describe "defaults" do

    it "should be able to update defaults for a resource" do
      r = compile_ruby_to_catalog(<<-MANIFEST)
        Notify.defaults :message => "foo"
      MANIFEST

      @catalog.should be_equivalent_to_catalog r
    end

    it "should be able to update defaults for a resource passing a block" do
      r = compile_ruby_to_catalog(<<-MANIFEST)
        Notify.defaults do |n|
          n.message = "foo"
        end
      MANIFEST

      @catalog.should be_equivalent_to_catalog r
    end
  end
end

