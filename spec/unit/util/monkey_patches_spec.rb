#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/monkey_patches'



describe "yaml deserialization" do
  it "should call yaml_initialize when deserializing objects that have that method defined" do
    class Puppet::TestYamlInitializeClass
      attr_reader :foo

      def yaml_initialize(tag, var)
        var.should == {'foo' => 100}
        instance_variables.should == []
        @foo = 200
      end
    end

    obj = YAML.load("--- !ruby/object:Puppet::TestYamlInitializeClass\n  foo: 100")
    obj.foo.should == 200
  end

  it "should not call yaml_initialize if not defined" do
    class Puppet::TestYamlNonInitializeClass
      attr_reader :foo
    end

    obj = YAML.load("--- !ruby/object:Puppet::TestYamlNonInitializeClass\n  foo: 100")
    obj.foo.should == 100
  end
end
