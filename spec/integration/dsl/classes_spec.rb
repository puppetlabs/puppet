require 'puppet'
require 'spec_helper'
require 'matchers/catalog'
require 'puppet_spec/compiler'

include PuppetSpec::Compiler

describe Puppet::DSL do
  before :each do
    prepare_compiler
  end

  describe "classes" do

    it "should be able to create a class" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do; end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "shouldn't evaluate the body of the class until it is used" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
          notify {"bar": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
          notify "bar"
        end
      MANIFEST
      r.should be_equivalent_to p
    end

    it "should be able to use created class" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
        }

        node default {
          include foo
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
        end

        node "default" do
          use :foo
        end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should evaluate contents of the class when the class is used" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
          notify {"bar": }
        }

        include foo
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
          notify "bar"
        end

        use :foo
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create class with arguments and use them" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo($param = "value") {}

      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo, :arguments => {:param => "value"} do; end
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to use class with arguments" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo($param = "value") {
          notify {"$param": }
        }

        class {"foo": param => "bar"}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo, :arguments => {:param => "value"} do
          notify params[:param]
        end

        use :foo, :param => "bar"
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should be able to create class with arguments with default values" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo($param = "value") {
          notify {"$param": }
        }

        class {"foo": param => "bar"}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo, :arguments => {:param => "value"} do
          notify params[:param]
        end

        use :foo, :param => "bar"
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should allow inheritance" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
          notify {"foo": }
        }

        class bar inherits foo {
          notify {"bar": }
        }
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
          notify "foo"
        end

        hostclass :bar, :inherits => :foo do
          notify "bar"
        end

        use :bar
      MANIFEST

      r.should be_equivalent_to p
    end

    it "should allow inheritance with arguments" do
      p = compile_to_catalog(<<-MANIFEST)
        class foo {
          notify {"foo": }
        }

        class bar($msg) inherits foo {
          notify {"bar": message => $msg}
        }

        class {"bar": msg => "foobarbaz"}
      MANIFEST

      r = compile_ruby_to_catalog(<<-MANIFEST)
        hostclass :foo do
          notify "foo"
        end

        hostclass :bar, :inherits => :foo, :arguments => {:msg => nil} do
          notify "bar", :message => params[:msg]
        end

        use "bar", :msg => "foobarbaz"
      MANIFEST
      r.resources.select {|r| r.name == "Notify/bar"}.first[:message].should == "foobarbaz"

      r.should be_equivalent_to p
    end

  end
end

