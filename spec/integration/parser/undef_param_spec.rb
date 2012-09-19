require 'spec_helper'
require 'puppet_spec/compiler'

describe "Undefined parameters should be handled so that" do
  include PuppetSpec::Compiler

  def expect_the_message_to_be(message, node = Puppet::Node.new('the node'))
    catalog = compile_to_catalog(yield, node)
    catalog.resource('Notify', 'something')[:message].should == message
  end

  def expect_puppet_error(message, node = Puppet::Node.new('the node'))
    expect { compile_to_catalog(yield, node) }.to raise_error(Puppet::Error, message)
  end
  before :each do
    Puppet.expects(:deprecation_warning).never
  end

  describe "when a value is given as parameter value" do
    it "it should override the default" do
      expect_the_message_to_be('2') do <<-MANIFEST
        node default {
          include foo
        }
        class foo {
          define a($x=1) { notify { 'something': message => $x }}
          a {'a': x => 2}
        }
        MANIFEST
      end
    end
  end

  describe "when 'undef' is given as parameter value" do
    it "the value should be set to 'undef'" do
      expect_the_message_to_be(true) do <<-MANIFEST
          node default {
            include foo
          }
          class foo {
            define a($x=1) { notify { 'something': message => $x == undef }}
            a {'a': x => undef}
          }
        MANIFEST
      end
    end
  end

  describe "when no value is given for a parameter" do
    it "the value should be set to the default" do
      expect_the_message_to_be('1') do <<-MANIFEST
          node default {
            include foo
          }
          class foo {
            define a($x=1) { notify { 'something': message => $x }}
            a {'a': }
          }
        MANIFEST
      end
    end
    it "and the default is set to undef, the value should be set to the default" do
      expect_the_message_to_be(true) do <<-MANIFEST
          node default {
            include foo
          }
          class foo {
            define a($x=undef) { notify { 'something': message => $x == undef}}
            a {'a': }
          }
      MANIFEST
      end
    end

    it "and no default is set should fail with error" do
      expect_puppet_error(/^Must pass x to Foo::A\[a\].*/) do <<-MANIFEST
          node default {
            include foo
          }
          class foo {
            define a($x) { notify { 'something': message => $x }}
            a {'a': }
          }
      MANIFEST
      end
    end
  end
end
