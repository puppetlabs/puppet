#!/usr/bin/env ruby

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')
require 'tmpdir'

describe Puppet::String::StringCollection do
  # To avoid cross-pollution we have to save and restore both the hash
  # containing all the string data, and the array used by require.  Restoring
  # both means that we don't leak side-effects across the code. --daniel 2011-04-06
  before :each do
    @original_strings  = subject.instance_variable_get("@strings").dup
    @original_required = $".dup
    subject.instance_variable_get("@strings").clear
  end

  after :each do
    subject.instance_variable_set("@strings", @original_strings)
    $".clear ; @original_required.each do |item| $" << item end
  end

  describe "::strings" do
    it "REVISIT: should have some tests here, if we describe it"
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
      subject.expects(:require).with('puppet/string/bar')
      subject.expects(:require).with('bar@0.0.1/puppet/string/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the default string for the specified version :current" do
      subject.expects(:require).never # except...
      subject.expects(:require).with('puppet/string/fozzie')
      subject['fozzie', :current]
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
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@strings")[:bar]['0.0.1'] = true
        file == 'puppet/string/bar'
      end
      subject.string?("bar", '0.0.1').should == true
    end

    it "should return true if requiring the string registered it" do
      subject.stubs(:require).with do
        subject.instance_variable_get("@strings")[:bar]['0.0.1'] = 20
      end
    end

    it "should require the string by version if the 'current' version isn't it" do
      subject.expects(:require).with('puppet/string/bar').
        raises(LoadError, 'no such file to load -- puppet/string/bar')
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@strings")[:bar]['0.0.1'] = true
        file == 'bar@0.0.1/puppet/string/bar'
      end
      subject.string?("bar", '0.0.1').should == true
    end

    it "should return false if the string is not registered" do
      subject.stubs(:require).returns(true)
      subject.string?("bar", '0.0.1').should == false
    end

    it "should return false if there is a LoadError requiring the string" do
      subject.stubs(:require).
        raises(LoadError, 'no such file to load -- puppet/string/bar').then.
        raises(LoadError, 'no such file to load -- bar@0.0.1/puppet/string/bar')
      subject.string?("bar", '0.0.1').should == false
    end

    it "should register the version loaded by `:current` as `:current`" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@strings")[:huzzah]['2.0.1'] = :huzzah_string
        file == 'puppet/string/huzzah'
      end
      subject.string?("huzzah", :current)
      subject.instance_variable_get("@strings")[:huzzah][:current].should == :huzzah_string
    end

    it "should register the version loaded from `puppet/string/{name}` as `:current`" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@strings")[:huzzah]['2.0.1'] = :huzzah_string
        file == 'puppet/string/huzzah'
      end
      subject.string?("huzzah", '2.0.1')
      subject.instance_variable_get("@strings")[:huzzah][:current].should == :huzzah_string
    end

    it "should not register the version loaded from `{name}@{version}` as `:current`" do
      subject.expects(:require).with('puppet/string/huzzah').
        raises(LoadError, 'no such file to load -- puppet/string/huzzah')
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@strings")[:huzzah]['0.0.1'] = true
        file == 'huzzah@0.0.1/puppet/string/huzzah'
      end
      subject.string?("huzzah", '0.0.1')
      subject.instance_variable_get("@strings")[:huzzah].should_not have_key(:current)
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
