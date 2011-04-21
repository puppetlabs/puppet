#!/usr/bin/env rspec
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
    $".delete_if do |path| path =~ %r{/face/.*\.rb$} end
    subject.instance_variable_get("@faces").clear
  end

  after :each do
    subject.instance_variable_set("@faces", @original_faces)
    $".clear ; @original_required.each do |item| $" << item end
  end

  describe "::prefix_match?" do
    #   want     have
    { ['1.0.0', '1.0.0'] => true,
      ['1.0',   '1.0.0'] => true,
      ['1',     '1.0.0'] => true,
      ['1.0.0', '1.1.0'] => false,
      ['1.0',   '1.1.0'] => false,
      ['1',     '1.1.0'] => true,
      ['1.0.1', '1.0.0'] => false,
    }.each do |data, result|
      it "should return #{result.inspect} for prefix_match?(#{data.join(', ')})" do
        subject.prefix_match?(*data).should == result
      end
    end
  end

  describe "::validate_version" do
    { '10.10.10'     => true,
      '1.2.3.4'      => false,
      '10.10.10beta' => true,
      '10.10'        => false,
      '123'          => false,
      'v1.1.1'       => false,
    }.each do |input, result|
      it "should#{result ? '' : ' not'} permit #{input.inspect}" do
        subject.validate_version(input).should(result ? be_true : be_false)
      end
    end
  end

  describe "::[]" do
    before :each do
      subject.instance_variable_get("@faces")[:foo]['0.0.1'] = 10
    end

    it "should return the face with the given name" do
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to load the face if it isn't found" do
      subject.expects(:require).with('puppet/face/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the default face for the specified version :current" do
      subject.expects(:require).with('puppet/face/fozzie')
      subject['fozzie', :current]
    end

    it "should return true if the face specified is registered" do
      subject.instance_variable_get("@faces")[:foo]['0.0.1'] = 10
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to require the face if it is not registered" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:bar]['0.0.1'] = true
        file == 'puppet/face/bar'
      end
      subject["bar", '0.0.1'].should be_true
    end

    it "should return false if the face is not registered" do
      subject.stubs(:require).returns(true)
      subject["bar", '0.0.1'].should be_false
    end

    it "should return false if the face file itself is missing" do
      subject.stubs(:require).
        raises(LoadError, 'no such file to load -- puppet/face/bar')
      subject["bar", '0.0.1'].should be_false
    end

    it "should register the version loaded by `:current` as `:current`" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:huzzah]['2.0.1'] = :huzzah_face
        file == 'puppet/face/huzzah'
      end
      subject["huzzah", :current]
      subject.instance_variable_get("@faces")[:huzzah][:current].should == :huzzah_face
    end

    context "with something on disk" do
      it "should register the version loaded from `puppet/face/{name}` as `:current`" do
        subject["huzzah", '2.0.1'].should be
        subject["huzzah", :current].should be
        Puppet::Face[:huzzah, '2.0.1'].should == Puppet::Face[:huzzah, :current]
      end

      it "should index :current when the code was pre-required" do
        subject.instance_variable_get("@faces")[:huzzah].should_not be_key :current
        require 'puppet/face/huzzah'
        subject[:huzzah, :current].should be_true
      end
    end

    it "should not cause an invalid face to be enumerated later" do
      subject[:there_is_no_face, :current].should be_false
      subject.faces.should_not include :there_is_no_face
    end
  end

  describe "::register" do
    it "should store the face by name" do
      face = Puppet::Face.new(:my_face, '0.0.1')
      subject.register(face)
      subject.instance_variable_get("@faces").should == {:my_face => {'0.0.1' => face}}
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
