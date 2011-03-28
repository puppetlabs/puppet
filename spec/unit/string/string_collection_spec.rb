#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'tmpdir'

describe Puppet::String::StringCollection do
  before :all do
    @strings = subject.instance_variable_get("@strings").dup
  end

  before :each do
    subject.instance_variable_get("@strings").clear
  end

  after :all do
    subject.instance_variable_set("@strings", @strings)
  end

  describe "::strings" do
  end

  describe "::versions" do
    before :each do
      @dir = Dir.mktmpdir
      @lib = FileUtils.mkdir_p(File.join @dir, 'puppet', 'string')
      $LOAD_PATH.push(@dir)
    end

    after :each do
      FileUtils.remove_entry_secure @dir
      $LOAD_PATH.pop
    end

    it "should return an empty array when no versions are loadable" do
      subject.versions(:fozzie).should == []
    end

    it "should return versions loadable as puppet/string/v{version}/{name}" do
      FileUtils.mkdir_p(File.join @lib, 'v1.0.0')
      FileUtils.touch(File.join @lib, 'v1.0.0', 'fozzie.rb')
      subject.versions(:fozzie).should == ['1.0.0']
    end

    it "should an ordered list of all versions loadable as puppet/string/v{version}/{name}" do
      %w[ 1.2.1rc2 1.2.1beta1 1.2.1rc1 1.2.1 1.2.2 ].each do |version|
        FileUtils.mkdir_p(File.join @lib, "v#{version}")
        FileUtils.touch(File.join @lib, "v#{version}", 'fozzie.rb')
      end
      subject.versions(:fozzie).should == %w[ 1.2.1beta1 1.2.1rc1 1.2.1rc2 1.2.1 1.2.2 ]
    end

    it "should not return a version for an empty puppet/string/v{version}/{name}" do
      FileUtils.mkdir_p(File.join @lib, 'v1.0.0', 'fozzie')
      subject.versions(:fozzie).should == []
    end

    it "should an ordered list of all versions loadable as puppet/string/v{version}/{name}/*.rb" do
      %w[ 1.2.1rc2 1.2.1beta1 1.2.1rc1 1.2.1 1.2.2 ].each do |version|
        FileUtils.mkdir_p(File.join @lib, "v#{version}", "fozzie")
        FileUtils.touch(File.join @lib, "v#{version}", 'fozzie', 'action.rb')
      end
      subject.versions(:fozzie).should == %w[ 1.2.1beta1 1.2.1rc1 1.2.1rc2 1.2.1 1.2.2 ]
    end
  end

  describe "::validate_version" do
    it 'should permit three number versions' do
      subject.validate_version('10.10.10').should == true
    end

    it 'should permit versions with appended descriptions' do
      subject.validate_version('10.10.10beta').should == true
    end

    it 'should not permit versions with more than three numbers' do
      subject.validate_version('1.2.3.4').should == false
    end

    it 'should not permit versions with only two numbers' do
      subject.validate_version('10.10').should == false
    end

    it 'should not permit versions with only one number' do
      subject.validate_version('123').should == false
    end

    it 'should not permit versions with text in any position but at the end' do
      subject.validate_version('v1.1.1').should == false
    end
  end

  describe "::compare_versions" do
    # (a <=> b) should be:
    #   -1 if a < b
    #   0  if a == b
    #   1  if a > b
    it 'should sort major version numbers numerically' do
      subject.compare_versions('1.0.0', '2.0.0').should == -1
      subject.compare_versions('2.0.0', '1.1.1').should == 1
      subject.compare_versions('2.0.0', '10.0.0').should == -1
    end

    it 'should sort minor version numbers numerically' do
      subject.compare_versions('0.1.0', '0.2.0').should == -1
      subject.compare_versions('0.2.0', '0.1.1').should == 1
      subject.compare_versions('0.2.0', '0.10.0').should == -1
    end

    it 'should sort tiny version numbers numerically' do
      subject.compare_versions('0.0.1', '0.0.2').should == -1
      subject.compare_versions('0.0.2', '0.0.1').should == 1
      subject.compare_versions('0.0.2', '0.0.10').should == -1
    end

    it 'should sort major version before minor version' do
      subject.compare_versions('1.1.0', '1.2.0').should == -1
      subject.compare_versions('1.2.0', '1.1.1').should == 1
      subject.compare_versions('1.2.0', '1.10.0').should == -1

      subject.compare_versions('1.1.0', '2.2.0').should == -1
      subject.compare_versions('2.2.0', '1.1.1').should == 1
      subject.compare_versions('2.2.0', '1.10.0').should == 1
    end

    it 'should sort minor version before tiny version' do
      subject.compare_versions('0.1.1', '0.1.2').should == -1
      subject.compare_versions('0.1.2', '0.1.1').should == 1
      subject.compare_versions('0.1.2', '0.1.10').should == -1

      subject.compare_versions('0.1.1', '0.2.2').should == -1
      subject.compare_versions('0.2.2', '0.1.1').should == 1
      subject.compare_versions('0.2.2', '0.1.10').should == 1
    end

    it 'should sort appended strings asciibetically' do
      subject.compare_versions('0.0.0a', '0.0.0b').should == -1
      subject.compare_versions('0.0.0beta1', '0.0.0beta2').should == -1
      subject.compare_versions('0.0.0beta1', '0.0.0rc1').should == -1
      subject.compare_versions('0.0.0beta1', '0.0.0alpha1').should == 1
      subject.compare_versions('0.0.0beta1', '0.0.0beta1').should == 0
    end

    it "should sort appended strings before 'whole' versions" do
      subject.compare_versions('0.0.1a', '0.0.1').should == -1
      subject.compare_versions('0.0.1', '0.0.1beta').should == 1
    end
  end

  describe "::[]" do
    before :each do
      subject.instance_variable_get("@strings")[:foo]['0.0.1'] = 10
    end

    before :each do
      @dir = Dir.mktmpdir
      @lib = FileUtils.mkdir_p(File.join @dir, 'puppet', 'string')
      $LOAD_PATH.push(@dir)
    end

    after :each do
      FileUtils.remove_entry_secure @dir
      $LOAD_PATH.pop
    end

    it "should return the string with the given name" do
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to load the string if it isn't found" do
      subject.expects(:require).with('puppet/string/v0.0.1/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the string with the greatest version for specified version :latest" do
      %w[ 1.2.1 1.2.2 ].each do |version|
        FileUtils.mkdir_p(File.join @lib, "v#{version}")
        FileUtils.touch(File.join @lib, "v#{version}", 'fozzie.rb')
      end
      subject.expects(:require).with('puppet/string/v1.2.2/fozzie')
      subject['fozzie', :latest]
    end
  end

  describe "::string?" do
    before :each do
      subject.instance_variable_get("@strings")[:foo]['0.0.1'] = 10
    end

    it "should return true if the string specified is registered" do
      subject.string?("foo", '0.0.1').should == true
    end

    it "should attempt to require the string if it is not registered" do
      subject.expects(:require).with('puppet/string/v0.0.1/bar')
      subject.string?("bar", '0.0.1')
    end

    it "should return true if requiring the string registered it" do
      subject.stubs(:require).with do
        subject.instance_variable_get("@strings")[:bar]['0.0.1'] = 20
      end
      subject.string?("bar", '0.0.1').should == true
    end

    it "should return false if the string is not registered" do
      subject.stubs(:require).returns(true)
      subject.string?("bar", '0.0.1').should == false
    end

    it "should return false if there is a LoadError requiring the string" do
      subject.stubs(:require).raises(LoadError)
      subject.string?("bar", '0.0.1').should == false
    end
  end

  describe "::register" do
    it "should store the string by name" do
      string = Puppet::String.new(:my_string, '0.0.1')
      subject.register(string)
      subject.instance_variable_get("@strings").should == {:my_string => {'0.0.1' => string}}
    end
  end

  describe "::underscorize" do
    faulty = [1, "#foo", "$bar", "sturm und drang", :"sturm und drang"]
    valid  = {
      "Foo"      => :foo,
      :Foo       => :foo,
      "foo_bar"  => :foo_bar,
      :foo_bar   => :foo_bar,
      "foo-bar"  => :foo_bar,
      :"foo-bar" => :foo_bar,
    }

    valid.each do |input, expect|
      it "should map #{input.inspect} to #{expect.inspect}" do
        result = subject.underscorize(input)
        result.should == expect
      end
    end

    faulty.each do |input|
      it "should fail when presented with #{input.inspect} (#{input.class})" do
        expect { subject.underscorize(input) }.
          should raise_error ArgumentError, /not a valid string name/
      end
    end
  end
end
