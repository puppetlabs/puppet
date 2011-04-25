#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/interface/action_builder'
require 'puppet/network/format_handler'

describe Puppet::Interface::ActionBuilder do
  let :face do Puppet::Interface.new(:puppet_interface_actionbuilder, '0.0.1') end

  it "should build an action" do
    action = Puppet::Interface::ActionBuilder.build(nil, :foo) do
    end
    action.should be_a(Puppet::Interface::Action)
    action.name.should == :foo
  end

  it "should define a method on the face which invokes the action" do
    face = Puppet::Interface.new(:action_builder_test_interface, '0.0.1') do
      action(:foo) { when_invoked { "invoked the method" } }
    end

    face.foo.should == "invoked the method"
  end

  it "should require a block" do
    expect { Puppet::Interface::ActionBuilder.build(nil, :foo) }.
      should raise_error("Action :foo must specify a block")
  end

  describe "when handling options" do
    it "should have a #option DSL function" do
      method = nil
      Puppet::Interface::ActionBuilder.build(face, :foo) do
        method = self.method(:option)
      end
      method.should be
    end

    it "should define an option without a block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        option "--bar"
      end
      action.should be_option :bar
    end

    it "should accept an empty block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        option "--bar" do
          # This space left deliberately blank.
        end
      end
      action.should be_option :bar
    end
  end

  describe "#inherit_options_from" do
    let :face do
      Puppet::Interface.new(:face_with_some_options, '0.0.1') do
        option '-w'

        action(:foo) do
          option '-x', '--ex'
          option '-y', '--why'
        end

        action(:bar) do
          option '-z', '--zee'
        end

        action(:baz) do
          option '-z', '--zed'
        end
      end
    end

    it 'should add the options from the specified action' do
      foo = face.get_action(:foo)
      action = Puppet::Interface::ActionBuilder.build(face, :inherit_options) do
        inherit_options_from foo
      end
      action.options.should == foo.options
    end

    it 'should add the options from multiple actions' do
      foo = face.get_action(:foo)
      bar = face.get_action(:bar)
      action = Puppet::Interface::ActionBuilder.build(face, :inherit_options) do
        inherit_options_from foo
        inherit_options_from bar
      end
      action.options.should == (foo.options + bar.options).uniq.sort
    end

    it 'should permit symbolic names for actions in the same face' do
      foo = face.get_action(:foo)
      action = Puppet::Interface::ActionBuilder.build(face, :inherit_options) do
        inherit_options_from :foo
      end
      action.options.should == foo.options
    end

    it 'should raise a useful error if you supply a bad action name' do
      expect do
        Puppet::Interface::ActionBuilder.build(face, :inherit_options) do
          inherit_options_from :nowhere
        end
      end.to raise_error /nowhere/
    end
  end

  context "inline documentation" do
    it "should set the summary" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        summary "this is some text"
      end
      action.summary.should == "this is some text"
    end
  end

  context "action defaulting" do
    it "should set the default to true" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        default
      end
      action.default.should be_true
    end

    it "should not be default by, er, default. *cough*" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do end
      action.default.should be_false
    end
  end

  context "#when_rendering" do
    it "should fail if no rendering format is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering do true end
        end
      }.to raise_error ArgumentError, /must give a rendering format to when_rendering/
    end

    it "should fail if no block is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering :json
        end
      }.to raise_error ArgumentError, /must give a block to when_rendering/
    end

    it "should fail if the block takes no arguments" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering :json do true end
        end
      }.to raise_error ArgumentError, /when_rendering methods take one argument, the result, not/
    end

    it "should fail if the block takes more than one argument" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering :json do |a, b, c| true end
        end
      }.to raise_error ArgumentError, /when_rendering methods take one argument, the result, not/
    end

    it "should fail if the block takes a variable number of arguments" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering :json do |*args| true end
        end
      }.to raise_error(ArgumentError,
                       /when_rendering methods take one argument, the result, not/)
    end

    it "should stash a rendering block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_rendering :json do |a| true end
      end
      action.when_rendering(:json).should be_an_instance_of Method
    end

    it "should fail if you try to set the same rendering twice" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_rendering :json do |a| true end
          when_rendering :json do |a| true end
        end
      }.to raise_error ArgumentError, /You can't define a rendering method for json twice/
    end

    it "should work if you set two different renderings" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_rendering :json do |a| true end
        when_rendering :yaml do |a| true end
      end
      action.when_rendering(:json).should be_an_instance_of Method
      action.when_rendering(:yaml).should be_an_instance_of Method
    end

    it "should be bound to the face when called" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_rendering :json do |a| self end
      end
      action.when_rendering(:json).call(true).should == face
    end
  end

  context "#render_as" do
    it "should default to nil (eg: based on context)" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do end
      action.render_as.should be_nil
    end

    it "should fail if not rendering format is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          render_as
        end
      }.to raise_error ArgumentError, /must give a rendering format to render_as/
    end

    Puppet::Network::FormatHandler.formats.each do |name|
      it "should accept #{name.inspect} format" do
        action = Puppet::Interface::ActionBuilder.build(face, :foo) do
          render_as name
        end
        action.render_as.should == name
      end
    end

    it "should accept :for_humans format" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        render_as :for_humans
      end
      action.render_as.should == :for_humans
    end

    [:if_you_define_this_format_you_frighten_me, "json", 12].each do |input|
      it "should fail if given #{input.inspect}" do
        expect {
          Puppet::Interface::ActionBuilder.build(face, :foo) do
            render_as input
          end
        }.to raise_error ArgumentError, /#{input.inspect} is not a valid rendering format/
      end
    end
  end
end
