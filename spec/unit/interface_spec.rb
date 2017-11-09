require 'spec_helper'
require 'puppet/face'
require 'puppet/interface'

describe Puppet::Interface do
  subject { Puppet::Interface }

  before :each do
    @faces = Puppet::Interface::FaceCollection.
      instance_variable_get("@faces").dup
    @dq = $".dup
    $".delete_if do |path| path =~ %r{/face/.*\.rb$} end
    Puppet::Interface::FaceCollection.instance_variable_get("@faces").clear
  end

  after :each do
    Puppet::Interface::FaceCollection.instance_variable_set("@faces", @faces)
    $".clear ; @dq.each do |item| $" << item end
  end

  describe "#[]" do
    it "should fail when no version is requested" do
      expect { subject[:huzzah] }.to raise_error ArgumentError
    end

    it "should raise an exception when the requested version is unavailable" do
      expect { subject[:huzzah, '17.0.0'] }.to raise_error(Puppet::Error, /Could not find version/)
    end

    it "should raise an exception when the requested face doesn't exist" do
      expect { subject[:burrble_toot, :current] }.to raise_error(Puppet::Error, /Could not find Puppet Face/)
    end

    describe "version matching" do
      { '1'     => '1.1.1',
        '1.0'   => '1.0.1',
        '1.0.1' => '1.0.1',
        '1.1'   => '1.1.1',
        '1.1.1' => '1.1.1'
      }.each do |input, expect|
        it "should match #{input.inspect} to #{expect.inspect}" do
          face = subject[:version_matching, input]
          expect(face).to be
          expect(face.version).to eq(expect)
        end
      end

      %w{1.0.2 1.2}.each do |input|
        it "should not match #{input.inspect} to any version" do
          expect { subject[:version_matching, input] }.
            to raise_error Puppet::Error, /Could not find version/
        end
      end
    end
  end

  describe "#define" do
    it "should register the face" do
      face  = subject.define(:face_test_register, '0.0.1')
      expect(face).to eq(subject[:face_test_register, '0.0.1'])
    end

    it "should load actions" do
      subject.any_instance.expects(:load_actions)
      subject.define(:face_test_load_actions, '0.0.1')
    end

    it "should require a version number" do
      expect { subject.define(:no_version) }.to raise_error ArgumentError
    end

    it "should support summary builder and accessor methods" do
      expect(subject.new(:foo, '1.0.0')).to respond_to(:summary).with(0).arguments
      expect(subject.new(:foo, '1.0.0')).to respond_to(:summary=).with(1).arguments
    end

    # Required documentation methods...
    { :summary     => "summary",
      :description => "This is the description of the stuff\n\nWhee",
      :examples    => "This is my example",
      :short_description => "This is my custom short description",
      :notes       => "These are my notes...",
      :author      => "This is my authorship data",
    }.each do |attr, value|
      it "should support #{attr} in the builder" do
        face = subject.new(:builder, '1.0.0') do
          self.send(attr, value)
        end
        expect(face.send(attr)).to eq(value)
      end
    end
  end

  describe "#initialize" do
    it "should require a version number" do
      expect { subject.new(:no_version) }.to raise_error ArgumentError
    end

    it "should require a valid version number" do
      expect { subject.new(:bad_version, 'Rasins') }.
        to raise_error ArgumentError
    end

    it "should instance-eval any provided block" do
      face = subject.new(:face_test_block, '0.0.1') do
        action(:something) do
          when_invoked {|_| "foo" }
        end
      end

      expect(face.something).to eq("foo")
    end
  end

  it "should have a name" do
    expect(subject.new(:me, '0.0.1').name).to eq(:me)
  end

  it "should stringify with its own name" do
    expect(subject.new(:me, '0.0.1').to_s).to match(/\bme\b/)
  end

  it "should try to require faces that are not known" do
    subject::FaceCollection.expects(:load_face).with(:foo, :current)
    subject::FaceCollection.expects(:load_face).with(:foo, '0.0.1')
    expect { subject[:foo, '0.0.1'] }.to raise_error Puppet::Error
  end

  describe 'when raising NoMethodErrors' do
    subject { described_class.new(:foo, '1.0.0') }

    it 'includes the face name in the error message' do
      expect { subject.boombaz }.to raise_error(NoMethodError, /#{subject.name}/)
    end

    it 'includes the face version in the error message' do
      expect { subject.boombaz }.to raise_error(NoMethodError, /#{subject.version}/)
    end
  end

  it_should_behave_like "things that declare options" do
    def add_options_to(&block)
      subject.new(:with_options, '0.0.1', &block)
    end
  end

  context "when deprecating a face" do
    let(:face) { subject.new(:foo, '0.0.1') }
    describe "#deprecate" do
      it "should respond to #deprecate" do
        expect(subject.new(:foo, '0.0.1')).to respond_to(:deprecate)
      end

      it "should set the deprecated value to true" do
        expect(face.deprecated?).to be_falsey
        face.deprecate
        expect(face.deprecated?).to be_truthy
      end
    end

    describe "#deprecated?" do
      it "should return a nil (falsey) value by default" do
        expect(face.deprecated?).to be_falsey
      end

      it "should return true if the face has been deprecated" do
        expect(face.deprecated?).to be_falsey
        face.deprecate
        expect(face.deprecated?).to be_truthy
      end
    end
  end

  describe "with face-level display_global_options" do
    it "should not return any action level display_global_options" do
      face = subject.new(:with_display_global_options, '0.0.1') do
        display_global_options "environment"
        action :baz do
          when_invoked {|_| true }
          display_global_options "modulepath"
        end
      end
      face.display_global_options =~ ["environment"]
    end

    it "should not fail when a face d_g_o duplicates an action d_g_o" do
      expect {
        subject.new(:action_level_display_global_options, '0.0.1') do
          action :bar do
            when_invoked {|_| true }
            display_global_options "environment"
          end
          display_global_options "environment"
        end
      }.to_not raise_error
    end

    it "should work when two actions have the same d_g_o" do
      face = subject.new(:with_display_global_options, '0.0.1') do
        action :foo do when_invoked {|_| true} ; display_global_options "environment" end
        action :bar do when_invoked {|_| true} ; display_global_options "environment" end
      end
      face.get_action(:foo).display_global_options =~ ["environment"]
      face.get_action(:bar).display_global_options =~ ["environment"]
    end
      
  end
  
  describe "with inherited display_global_options" do
  end

  describe "with face-level options" do
    it "should not return any action-level options" do
      face = subject.new(:with_options, '0.0.1') do
        option "--foo"
        option "--bar"
        action :baz do
          when_invoked {|_| true }
          option "--quux"
        end
      end
      expect(face.options).to match_array([:foo, :bar])
    end

    it "should fail when a face option duplicates an action option" do
      expect {
        subject.new(:action_level_options, '0.0.1') do
          action :bar do
            when_invoked {|_| true }
            option "--foo"
          end
          option "--foo"
        end
      }.to raise_error ArgumentError, /Option foo conflicts with existing option foo on/i
    end

    it "should work when two actions have the same option" do
      face = subject.new(:with_options, '0.0.1') do
        action :foo do when_invoked {|_| true } ; option "--quux" end
        action :bar do when_invoked {|_| true } ; option "--quux" end
      end

      expect(face.get_action(:foo).options).to match_array([:quux])
      expect(face.get_action(:bar).options).to match_array([:quux])
    end

    it "should only list options and not aliases" do
      face = subject.new(:face_options, '0.0.1') do
        option "--bar", "-b", "--foo-bar"
      end
      expect(face.options).to match_array([:bar])
    end

  end

  describe "with inherited options" do
    let :parent do
      parent = Class.new(subject)
      parent.option("--inherited")
      parent.action(:parent_action) do when_invoked {|_| true } end
      parent
    end

    let :face do
      face = parent.new(:example, '0.2.1')
      face.option("--local")
      face.action(:face_action) do when_invoked {|_| true } end
      face
    end

    describe "#options" do
      it "should list inherited options" do
        expect(face.options).to match_array([:inherited, :local])
      end

      it "should see all options on face actions" do
        expect(face.get_action(:face_action).options).to match_array([:inherited, :local])
      end

      it "should see all options on inherited actions accessed on the subclass" do
        expect(face.get_action(:parent_action).options).to match_array([:inherited, :local])
      end

      it "should not see subclass actions on the parent class" do
        expect(parent.options).to match_array([:inherited])
      end

      it "should not see subclass actions on actions accessed on the parent class" do
        expect(parent.get_action(:parent_action).options).to match_array([:inherited])
      end
    end

    describe "#get_option" do
      it "should return an inherited option object" do
        expect(face.get_option(:inherited)).to be_an_instance_of subject::Option
      end
    end
  end

  it_should_behave_like "documentation on faces" do
    subject do
      Puppet::Interface.new(:face_documentation, '0.0.1')
    end
  end
end
