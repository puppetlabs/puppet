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
    subject.instance_variable_get(:@faces).clear
    subject.instance_variable_set(:@loaded, false)
  end

  after :each do
    subject.instance_variable_set(:@faces, @original_faces)
    @original_required.each {|f| $".push f unless $".include? f }
  end

  describe "::[]" do
    before :each do
      subject.instance_variable_get("@faces")[:foo][SemVer.new('0.0.1')] = 10
    end

    it "should return the face with the given name" do
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to load the face if it isn't found" do
      subject.expects(:require).once.with('puppet/face/bar')
      subject.expects(:require).once.with('puppet/face/0.0.1/bar')
      subject["bar", '0.0.1']
    end

    it "should attempt to load the default face for the specified version :current" do
      subject.expects(:require).with('puppet/face/fozzie')
      subject['fozzie', :current]
    end

    it "should return true if the face specified is registered" do
      subject.instance_variable_get("@faces")[:foo][SemVer.new('0.0.1')] = 10
      subject["foo", '0.0.1'].should == 10
    end

    it "should attempt to require the face if it is not registered" do
      subject.expects(:require).with do |file|
        subject.instance_variable_get("@faces")[:bar][SemVer.new('0.0.1')] = true
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
        raises(LoadError, 'no such file to load -- puppet/face/bar').then.
        raises(LoadError, 'no such file to load -- puppet/face/0.0.1/bar')
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

  describe "::get_action_for_face" do
    it "should return an action on the current face" do
      Puppet::Face::FaceCollection.get_action_for_face(:huzzah, :bar, :current).
        should be_an_instance_of Puppet::Interface::Action
    end

    it "should return an action on an older version of a face" do
      action = Puppet::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      action.should be_an_instance_of Puppet::Interface::Action
      action.face.version.should == SemVer.new('1.0.0')
    end

    it "should load the full older version of a face" do
      action = Puppet::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      action.face.version.should == SemVer.new('1.0.0')
      action.face.should be_action :obsolete_in_core
    end

    it "should not add obsolete actions to the current version" do
      action = Puppet::Face::FaceCollection.
        get_action_for_face(:huzzah, :obsolete, :current)

      action.face.version.should == SemVer.new('1.0.0')
      action.face.should be_action :obsolete_in_core

      current = Puppet::Face[:huzzah, :current]
      current.version.should == SemVer.new('2.0.1')
      current.should_not be_action :obsolete_in_core
      current.should_not be_action :obsolete
    end
  end

  describe "::register" do
    it "should store the face by name" do
      face = Puppet::Face.new(:my_face, '0.0.1')
      subject.register(face)
      subject.instance_variable_get("@faces").should == {
        :my_face => { face.version => face }
      }
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

  context "faulty faces" do
    before :each do
      $:.unshift "#{PuppetSpec::FIXTURE_DIR}/faulty_face"
    end

    after :each do
      $:.delete_if {|x| x == "#{PuppetSpec::FIXTURE_DIR}/faulty_face"}
    end

    it "should not die if a face has a syntax error" do
      subject.faces.should be_include :help
      subject.faces.should_not be_include :syntax
      @logs.should_not be_empty
      @logs.first.message.should =~ /syntax error/
    end
  end
end
