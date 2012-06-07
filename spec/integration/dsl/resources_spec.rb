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
        define "foo" do
          notice "foo"
        end
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
        define :foo, :arguments => {:msg => nil} do
          notice params[:msg]
        end
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
        define :foo do
          notice "foo"
        end

        foo "foo"
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
        define :foo do
          notice "foo"
        end

        node 'default' do
          foo "foo"
        end
      MANIFEST

      r.should == p
    end

    it "should be able to use defined resource in a class" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo() {
          notice($name)
        }

        class bar {
          foo {"foo": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo do
          notice params[:name]
        end

        hostclass :bar do
          foo "foo"
        end
      MANIFEST

      r.should == p
    end

    it "should be able to export resources" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($msg = "bar") {
          notify {$msg: message => $msg}
        }

        node default {
          @@foo {"foobar":}

          Foo <<| |>>
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo, :arguments => {:msg => "bar"} do
          notify params[:msg], :message => params[:msg]
        end

        node "default" do
          export do
            foo "foobar"
          end

          Resource::Foo.collect
        end
      MANIFEST

      p.should == r
    end

    it "should be able to virtualise resources" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($msg = "bar") {
          notify {$msg: message => $msg}
        }

        node default {
          @foo {"foobar":}

          Foo <| |>
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo, :arguments => {:msg => "bar"} do
          notify params[:msg], :message => params[:msg]
        end

        node "default" do
          virtual do
            foo "foobar"
          end

          Resource::Foo.realise
        end
      MANIFEST

      p.should == r
    end

    context "references" do
      before :each do
        @catalog = compile_to_catalog(<<-MANIFEST)
                     file {"redis.conf": owner => root}

                     service {"redis": require => File['redis.conf']}
                   MANIFEST
      end

      it "should be able to reference other resources" do
        compile_ruby_to_catalog(<<-MANIFEST).should == @catalog
          file "redis.conf", :owner => "root"

          service "redis", :require => Resource::File["redis.conf"]
        MANIFEST
      end

      it "should be able to reference other resources using a block" do
        compile_ruby_to_catalog(<<-MANIFEST).should == @catalog
          file "redis.conf", :owner => "root"

          service "redis" do
            require = Resource::File["redis.conf"]
          end
        MANIFEST
      end
    end

  end
end

