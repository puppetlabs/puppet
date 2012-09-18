require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  prepare_compiler

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

      r.should be_equivalent_to_catalog p
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

      r.should be_equivalent_to_catalog p
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

      r.should be_equivalent_to_catalog p
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

      r.should be_equivalent_to_catalog p
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

      r.should be_equivalent_to_catalog p
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

          Foo.collect
        end
      MANIFEST

      p.should be_equivalent_to_catalog r
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

          Foo.realise
        end
      MANIFEST

      p.should be_equivalent_to_catalog r
    end

    context "references" do
      before :each do
        @catalog = compile_to_catalog(<<-MANIFEST)
                     file {"redis.conf": owner => root}

                     service {"redis": require => File['redis.conf']}
                   MANIFEST
      end

      it "should be able to reference other resources" do
        compile_ruby_to_catalog(<<-MANIFEST).should be_equivalent_to_catalog @catalog
          file "redis.conf", :owner => "root"

          service "redis", :require => File["redis.conf"]
        MANIFEST
      end

      it "should be able to reference other resources using a block" do
        r = compile_ruby_to_catalog(<<-MANIFEST).should be_equivalent_to_catalog @catalog
          file "redis.conf", :owner => "root"

          service "redis" do |s|
            s.require = File["redis.conf"]
          end
        MANIFEST
      end
    end

  end
end

