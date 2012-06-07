require 'puppet'
require 'spec_helper'
require 'puppet_spec/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Catalog
include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
    @catalog = compile_to_catalog(<<-MANIFEST)
                 Notify {
                   message => "foo"
                 }
               MANIFEST
  end

  describe "defaults" do

    it "should be able to update defaults for a resource" do
      r = compile_ruby_to_catalog(<<-MANIFEST)
        Resource::Notify.defaults :message => "foo"
        end
      MANIFEST

      @catalog.should == r
    end

    it "should be able to update defaults for a resource passing a block" do
      r = compile_ruby_to_catalog(<<-MANIFEST)
        Resource::Notify.defaults :message => "foo"
      MANIFEST

      @catalog.should == r
    end
  end
end

