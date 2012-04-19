require 'spec_helper'
require 'puppet_spec/compiler'

describe "Two step scoping for variables" do
  include PuppetSpec::Compiler

  def expect_the_message_to_be(message) 
    catalog = compile_to_catalog(yield)
    catalog.resource('Notify', 'something')[:message].should == message
  end

  before :each do
    Puppet.expects(:deprecation_warning).never
  end

  describe "when using shadowing and inheritance" do
    it "finds value define in the inherited node" do
      expect_the_message_to_be('parent_msg') do <<-MANIFEST
          $var = "top_msg"
          node parent {
            $var = "parent_msg"
          }
          node default inherits parent {
            include foo
          }
          class foo {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end

    it "finds top scope when the class is included before the node defines the var" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
          $var = "top_msg"
          node parent {
            include foo
          }
          node default inherits parent {
            $var = "default_msg"
          }
          class foo {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end

    it "finds top scope when the class is included before the node defines the var" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
          $var = "top_msg"
          node parent {
            include foo
          }
          node default inherits parent {
            $var = "default_msg"
          }
          class foo {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end


    it "should find values in its local scope" do
      expect_the_message_to_be('local_msg') do <<-MANIFEST
          node default {
            include baz
          }
          class foo {
          }
          class bar inherits foo {
            $var = "local_msg"
            notify { 'something': message => $var, }
          }
          class baz {
            include bar
          }
        MANIFEST
      end
    end

    it "should find values in its inherited scope" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
          node default {
            include baz
          }
          class foo {
            $var = "foo_msg"
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            include bar
          }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those in the node (with intermediate inclusion)" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include baz
          }
          class foo {
            $var = "foo_msg"
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            include bar
          }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those in the node (without intermediate inclusion)" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include bar
          }
          class foo {
            $var = "foo_msg"
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end

    it "prefers values in its inherited scope over those from where it is included" do
      expect_the_message_to_be('foo_msg') do <<-MANIFEST
          node default {
            include baz
          }
          class foo {
            $var = "foo_msg"
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            $var = "baz_msg"
            include bar
          }
        MANIFEST
      end
    end

    it "does not used variables from classes included in the inherited scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include bar
          }
          class quux {
            $var = "quux_msg"
          }
          class foo inherits quux {
          }
          class baz {
            include foo
          }
          class bar inherits baz {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end

    it "does not use a variable from a scope lexically enclosing it" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include other::bar
          }
          class other {
            $var = "other_msg"
            class bar {
              notify { 'something': message => $var, }
            }
          }
        MANIFEST
      end
    end

    it "finds values in its node scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include baz
          }
          class foo {
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            include bar
          }
        MANIFEST
      end
    end

    it "finds values in its top scope" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
          $var = "top_msg"
          node default {
            include baz
          }
          class foo {
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            include bar
          }
        MANIFEST
      end
    end

    it "prefers variables from the node over those in the top scope" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          $var = "top_msg"
          node default {
            $var = "node_msg"
            include foo
          }
          class foo {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end
  end

  describe "in situations that used to have dynamic lookup" do
    it "ignores the dynamic value of the var" do
      expect_the_message_to_be('node_msg') do <<-MANIFEST
          node default {
            $var = "node_msg"
            include foo
          }
          class baz {
            $var = "baz_msg"
            include bar
          }
          class foo inherits baz {
          }
          class bar {
            notify { 'something': message => $var, }
          }
        MANIFEST
      end
    end

    it "finds nil when the only set variable is in the dynamic scope" do
      expect_the_message_to_be(nil) do <<-MANIFEST
          node default {
            include baz
          }
          class foo {
          }
          class bar inherits foo {
            notify { 'something': message => $var, }
          }
          class baz {
            $var = "baz_msg"
            include bar
          }
        MANIFEST
      end
    end
  end

  describe "using plussignment to change in a new scope" do
    it "does not change a string in the parent scope" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
          $var = "top_msg"
          class override {
            $var += "override"
            include foo
          }
          class foo {
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end

    it "does not change an array in the parent scope" do
      expect_the_message_to_be('top_msg') do <<-MANIFEST
          $var = ["top_msg"]
          class override {
            $var += ["override"]
            include foo
          }
          class foo {
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end

    it "concatenates two arrays" do
      expect_the_message_to_be(['top_msg', 'override']) do <<-MANIFEST
          $var = ["top_msg"]
          class override {
            $var += ["override"]
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end

    it "leaves an array of arrays unflattened" do
      expect_the_message_to_be([['top_msg'], ['override']]) do <<-MANIFEST
          $var = [["top_msg"]]
          class override {
            $var += [["override"]]
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end

    it "does not change a hash in the parent scope" do
      expect_the_message_to_be({"key"=>"top_msg"}) do <<-MANIFEST
          $var = { "key" => "top_msg" }
          class override {
            $var += { "other" => "override" }
            include foo
          }
          class foo {
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end

    it "replaces a value of a key in the hash instead of merging the values" do
      expect_the_message_to_be({"key"=>"override"}) do <<-MANIFEST
          $var = { "key" => "top_msg" }
          class override {
            $var += { "key" => "override" }
            notify { 'something': message => $var, }
          }

          include override
        MANIFEST
      end
    end
  end
end

