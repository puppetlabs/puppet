#!/usr/bin/env ruby
require 'spec_helper'

require 'tmpdir'
require 'puppet/interface/face_collection'

describe Puppet::Interface::FaceCollection do
  # To avoid cross-pollution we have to save and restore both the hash
  # containing all the interface data, and the array used by require.  Restoring
  # both means that we don't leak side-effects across the code. --daniel 2011-04-06
  #
  # Worse luck, we *also* need to flush $" of anything defining a face,
  # because otherwise we can cross-pollute from other test files and end up
  # with no faces loaded, but the require value set true. --daniel 2011-04-10
  before :each do
    @original_faces    = subject.instance_variable_get("@faces").dup
    @original_required = $".dup
    $".delete_if do |path| path =~ %r{/faces/.*\.rb$} end
    subject.instance_variable_get("@faces").clear
  end

  after :each do
    subject.instance_variable_set("@faces", @original_faces)
    $".clear ; @original_required.each do |item| $" << item end
  end

  describe "::faces" do
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
      subject.instance_variable_get("@faces")[:foo]['0.0.1'] = 10
    end

    before :each do
      @dir = Dir.mktmpdir
      @lib = FileUtils.mkdir_p(File.join @dir, 'puppet', 'faces')
      $LOAD_PATH.push(@dir)
    end

    after :each do
      FileUtils.remove_entry_secure @dir
      $LOAD_PATH.pop
    end

    it "should return the faces with the given name" do
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to load the faces if it isn't found" do
      subject.expects(:require).with('puppet/faces/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the default faces for the specified version :current" do
      subject.expects(:require).with('puppet/faces/fozzie')
      subject['fozzie', :current]
    end
  end

  describe "::face?" do
    it "should return true if the faces specified is registered" do
      subject.instance_variable_get("@faces")[:foo]['0.0.1'] = 10
      subject.face?("foo", '0.0.1').should == true
    end

    it "should attempt to require the faces if it is not registered" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:bar]['0.0.1'] = true
        file == 'puppet/faces/bar'
      end
      subject.face?("bar", '0.0.1').should == true
    end

    it "should return true if requiring the faces registered it" do
      subject.stubs(:require).with do
        subject.instance_variable_get("@faces")[:bar]['0.0.1'] = 20
      end
    end

    it "should return false if the faces is not registered" do
      subject.stubs(:require).returns(true)
      subject.face?("bar", '0.0.1').should be_false
    end

    it "should return false if the faces file itself is missing" do
      subject.stubs(:require).
        raises(LoadError, 'no such file to load -- puppet/faces/bar')
      subject.face?("bar", '0.0.1').should be_false
    end

    it "should register the version loaded by `:current` as `:current`" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:huzzah]['2.0.1'] = :huzzah_faces
        file == 'puppet/faces/huzzah'
      end
      subject.face?("huzzah", :current)
      subject.instance_variable_get("@faces")[:huzzah][:current].should == :huzzah_faces
    end

    context "with something on disk" do
      it "should register the version loaded from `puppet/faces/{name}` as `:current`" do
        subject.should be_face "huzzah", '2.0.1'
        subject.should be_face "huzzah", :current
        Puppet::Faces[:huzzah, '2.0.1'].should == Puppet::Faces[:huzzah, :current]
      end

      it "should index :current when the code was pre-required" do
        subject.instance_variable_get("@faces")[:huzzah].should_not be_key :current
        require 'puppet/faces/huzzah'
        subject.face?(:huzzah, :current).should be_true
      end
    end
  end

  describe "::register" do
    it "should store the faces by name" do
      faces = Puppet::Faces.new(:my_faces, '0.0.1')
      subject.register(faces)
      subject.instance_variable_get("@faces").should == {:my_faces => {'0.0.1' => faces}}
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
          should raise_error ArgumentError, /not a valid face name/
      end
    end
  end
end
