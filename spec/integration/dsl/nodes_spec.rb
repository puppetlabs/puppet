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

      r.should == p
    end

    it "should be able to create named node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "example.com" {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "example.com" do
          notice "foo"
        end
      MANIFEST

      r.should == p
    end

    it "should be able to create node with regexp" do
      p = compile_to_catalog(<<-MANIFEST)
        node /^www\./ {
          notice("foo")
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node /^www\./" do
          notice "foo"
        end
      MANIFEST

      r.should == p
    end

    it "should be able to create node inheriting from another node" do
      p = compile_to_catalog(<<-MANIFEST)
        node "base.example.com" {
          file { '/tmp/test':
            mode   => 0644,
            ensure => present
          }

        }

        node "child.example.com" inherits "base.example.com" {
          File['/tmp/test'] { mode => 0755 }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "base.example.com" do
          file '/tmp/test', :mode => 644, :ensure => :present
        end

        node "child.example.com", :inherits => "base.example.com" do
          Resource::File['/tmp/test'].override :mode => 755
        end
      MANIFEST

      r.should == p
    end

  end
end

