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

describe Range do
  def do_test( range, other, expected )
    result = range.intersection(other)
    result.should == expected
  end

  it "should return expected ranges for iterable things" do
    iterable_tests = {
      1  .. 4   => nil,          # before
      11 .. 15  => nil,          # after
      1  .. 6   => 5  ..  6,     # overlap_begin
      9  .. 15  => 9  ..  10,    # overlap_end
      1  .. 5   => 5  ..  5,     # overlap_begin_edge
      10 .. 15  => 10 ..  10,    # overlap_end_edge
      5  .. 10  => 5  ..  10,    # overlap_all
      6  .. 9   => 6  ..  9,     # overlap_inner

      1 ... 5   => nil,          # before             (exclusive range)
      1 ... 7   => 5  ... 7,     # overlap_begin      (exclusive range)
      1 ... 6   => 5  ... 6,     # overlap_begin_edge (exclusive range)
      5 ... 11  => 5  ..  10,    # overlap_all        (exclusive range)
      6 ... 10  => 6  ... 10,    # overlap_inner      (exclusive range)
    }

    iterable_tests.each do |other, expected|
      do_test( 5..10, other, expected )
      do_test( other, 5..10, expected )
    end
  end

  it "should return expected ranges for noniterable things" do
    inclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ..  10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => 10.to_f ..  10.to_f,   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ..  10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ..  10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    inclusive_base_case.each do |other, expected|
      do_test( 5.to_f..10.to_f, other, expected )
      do_test( other, 5.to_f..10.to_f, expected )
    end

    exclusive_base_case = {
      1.to_f  .. 4.to_f   => nil,                   # before
      11.to_f .. 15.to_f  => nil,                   # after
      1.to_f  .. 6.to_f   => 5.to_f  ..  6.to_f,    # overlap_begin
      9.to_f  .. 15.to_f  => 9.to_f  ... 10.to_f,   # overlap_end
      1.to_f  .. 5.to_f   => 5.to_f  ..  5.to_f,    # overlap_begin_edge
      10.to_f .. 15.to_f  => nil,                   # overlap_end_edge
      5.to_f  .. 10.to_f  => 5.to_f  ... 10.to_f,   # overlap_all
      6.to_f  .. 9.to_f   => 6.to_f  ..  9.to_f,    # overlap_inner

      1.to_f ... 5.to_f   => nil,                   # before             (exclusive range)
      1.to_f ... 7.to_f   => 5.to_f  ... 7.to_f,    # overlap_begin      (exclusive range)
      1.to_f ... 6.to_f   => 5.to_f  ... 6.to_f,    # overlap_begin_edge (exclusive range)
      5.to_f ... 11.to_f  => 5.to_f  ... 10.to_f,   # overlap_all        (exclusive range)
      6.to_f ... 10.to_f  => 6.to_f  ... 10.to_f,   # overlap_inner      (exclusive range)
    }

    exclusive_base_case.each do |other, expected|
      do_test( 5.to_f...10.to_f, other, expected )
      do_test( other, 5.to_f...10.to_f, expected )
    end
  end
end
