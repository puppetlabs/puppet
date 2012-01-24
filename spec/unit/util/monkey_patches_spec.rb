#!/usr/bin/env rspec
require 'spec_helper'

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

# In Ruby > 1.8.7 this is a builtin, otherwise we monkey patch the method in
describe "Array#combination" do
  it "should fail if wrong number of arguments given" do
    lambda { [1,2,3].combination() }.should raise_error(ArgumentError, /wrong number/)
    lambda { [1,2,3].combination(1,2) }.should raise_error(ArgumentError, /wrong number/)
  end

  it "should return an empty array if combo size than array size or negative" do
    [1,2,3].combination(4).to_a.should == []
    [1,2,3].combination(-1).to_a.should == []
  end

  it "should return an empty array with an empty array if combo size == 0" do
    [1,2,3].combination(0).to_a.should == [[]]
  end

  it "should all provide all combinations of size passed in" do
    [1,2,3,4].combination(1).to_a.should == [[1], [2], [3], [4]]
    [1,2,3,4].combination(2).to_a.should == [[1, 2], [1, 3], [1, 4], [2, 3], [2, 4], [3, 4]]
    [1,2,3,4].combination(3).to_a.should == [[1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4]]
  end
end

describe IO do
  include PuppetSpec::Files

  let(:file) { tmpfile('io-binary') }
  let(:content) { "\x01\x02\x03\x04" }

  describe "::binread" do
    it "should read in binary mode" do
      File.open(file, 'wb') {|f| f.write(content) }
      IO.binread(file).should == content
    end

    it "should read with a length and offset" do
      offset = 1
      length = 2
      File.open(file, 'wb') {|f| f.write(content) }
      IO.binread(file, length, offset).should == content[offset..length]
    end

    it "should raise an error if the file doesn't exist" do
      expect { IO.binread('/path/does/not/exist') }.to raise_error(Errno::ENOENT)
    end
  end

  describe "::binwrite" do
    it "should write in binary mode" do
      IO.binwrite(file, content).should == content.length
      File.open(file, 'rb') {|f| f.read.should == content }
    end

    it "should write using an offset" do
      offset = 1
      IO.binwrite(file, content, offset).should == content.length - offset
      File.open(file, 'rb') {|f| f.read.should == content[offset..-1] }
    end

    it "should raise an error if the file doesn't exist" do
      expect { IO.binwrite('/path/does/not/exist', 'foo') }.to raise_error(Errno::ENOENT)
    end
  end
end
