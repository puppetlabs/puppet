require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "relationships" do
    it "allows requiring resources" do
      p = compile_to_catalog(<<-'END')
        define foo() {
          notify {"foo": message => "foo" }
        }
        define bar() {
          notify {"bar": message => "bar" }
        }

        node "default" {
          bar {"bar": }
          foo {"foo": require => Bar["bar"] }
        }
      END

      r = compile_ruby_to_catalog(<<-'END')
        define :foo do
          notify "foo", :message => "foo"
        end

        define :bar do
          notify "bar", :message => "bar"
        end

        node "default" do
          bar "bar"
          foo "foo", :require => Bar["bar"]
        end
      END

      r.should be_equivalent_to p
    end

  end
end

