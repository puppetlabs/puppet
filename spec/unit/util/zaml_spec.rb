#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/util/monkey_patches'

describe "Pure ruby yaml implementation" do
  {
  7            => "--- 7",
  3.14159      => "--- 3.14159",
  'test'       => "--- test",
  []           => "--- []",
  :symbol      => "--- !ruby/sym symbol",
  {:a => "A"}  => "--- \n  !ruby/sym a: A",
  {:a => "x\ny"} => "--- \n  !ruby/sym a: |-\n    x\n    y" 
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

  it "should emit proper labels and backreferences for common objects" do
    # Note: this test makes assumptions about the names ZAML chooses
    # for labels.
    x = [1, 2]
    y = [3, 4]
    z = [x, y, x, y]
    z.to_yaml.should == "--- \n  - &id001\n    - 1\n    - 2\n  - &id002\n    - 3\n    - 4\n  - *id001\n  - *id002"
    z2 = YAML.load(z.to_yaml)
    z2.should == z
    z2[0].should equal(z2[2])
    z2[1].should equal(z2[3])
  end

  it "should emit proper labels and backreferences for recursive objects" do
    x = [1, 2]
    x << x
    x.to_yaml.should == "--- &id001\n  \n  - 1\n  - 2\n  - *id001"
    x2 = YAML.load(x.to_yaml)
    x2.should be_a(Array)
    x2.length.should == 3
    x2[0].should == 1
    x2[1].should == 2
    x2[2].should equal(x2)
  end
end
