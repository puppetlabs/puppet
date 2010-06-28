#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/monkey_patches'

describe "Pure ruby yaml implementation" do
    {
    7            => "--- 7",
    3.14159      => "--- 3.14159",
    'test'       => "--- test",
    []           => "--- []",
    :symbol      => "--- !ruby/sym symbol",
    {:a => "A"}  => "--- \n  !ruby/sym a: A"
    }.each { |o,y| 
        it "should convert the #{o.class} #{o.inspect} to yaml" do
            o.to_yaml.should == y
        end
        it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
            YAML.load(o.to_yaml).should == o
        end
    }
    #
    # Can't test for equality on raw objects
    {
    Object.new                   => "--- !ruby/object {}",
    [Object.new]                 => "--- \n  - !ruby/object {}",
    {Object.new => Object.new}   => "--- \n  ? !ruby/object {}\n  : !ruby/object {}"
    }.each { |o,y| 
        it "should convert the #{o.class} #{o.inspect} to yaml" do
            o.to_yaml.should == y
        end
        it "should produce yaml for the #{o.class} #{o.inspect} that can be reconstituted" do
            lambda { YAML.load(o.to_yaml) }.should_not raise_error
        end
    }
end

