require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "params" do

    it "should be able to set and read a variable" do
      p = compile_to_catalog(<<-MANIFEST)
        node default {
          $asdf = "foo"

          notify {"$asdf": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        node "default" do
          params[:asdf] = "foo"

          notify params[:asdf]
        end
      MANIFEST
      r.resources.map(&:name).should include "Notify/foo"

      r.should be_equivalent_to p
    end

    it "should be able to read params for a resource" do
      p = compile_to_catalog(<<-MANIFEST)
        define foo($msg) {
          notify {"$msg": }
        }

        foo {"foo": msg => "asdf"}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        define :foo, :arguments => {:msg => nil} do
          notify params[:msg]
        end

        foo :foo, :msg => "asdf"
      MANIFEST
      r.resources.map(&:name).should include "Notify/asdf"

      r.should be_equivalent_to p
    end

    context "defined in outer scope" do
      it "should available in inner scope" do
        p = compile_to_catalog(<<-MANIFEST)
          $foobar = "baz"
          define foo() {
            notify {"$foobar": }
          }

          foo {"foo": }
        MANIFEST

        r = compile_ruby_to_catalog(<<-MANIFEST)
          params[:foobar] = "baz"

          define :foo do
            notify params[:foobar]
          end

          foo :foo
        MANIFEST
        r.resources.map(&:name).should include "Notify/baz"

        r.should be_equivalent_to p
      end

      it "should be overwritten in inner scope" do
        p = compile_to_catalog(<<-MANIFEST)
          $foobar = "baz"
          define foo() {
            $foobar = "asdf"
            notify {"$foobar": }
          }

          foo {"foo": }
        MANIFEST

        r = compile_ruby_to_catalog(<<-MANIFEST)
          params[:foobar] = "baz"

          define :foo do
            params[:foobar] = "asdf"
            notify params[:foobar]
          end

          foo :foo
        MANIFEST
        r.resources.map(&:name).should include "Notify/asdf"

        r.should be_equivalent_to p
      end

      it "should not be overwritten in outer scope" do
        p = compile_to_catalog(<<-MANIFEST)
          $foobar = "baz"
          define foo() {
            $foobar = "asdf"
            notify {"$foobar": }
          }

          notify {"$foobar": }

          foo {"foo": }
        MANIFEST

        r = compile_ruby_to_catalog(<<-MANIFEST)
          params[:foobar] = "baz"

          define :foo do
            params[:foobar] = "asdf"
            notify params[:foobar]
          end

          notify params[:foobar]

          foo :foo
        MANIFEST
        r.resources.map(&:name).tap do |names|
          %w[asdf baz].each do |name|
            names.should include "Notify/#{name}"
          end
        end

        r.should be_equivalent_to p


      end

    end

  end
end

