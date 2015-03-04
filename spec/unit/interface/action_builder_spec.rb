#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/interface'
require 'puppet/network/format_handler'

describe Puppet::Interface::ActionBuilder do
  let :face do Puppet::Interface.new(:puppet_interface_actionbuilder, '0.0.1') end

  it "should build an action" do
    action = Puppet::Interface::ActionBuilder.build(face, :foo) do
      when_invoked do |options| true end
    end
    expect(action).to be_a(Puppet::Interface::Action)
    expect(action.name).to eq(:foo)
  end

  it "should define a method on the face which invokes the action" do
    face = Puppet::Interface.new(:action_builder_test_interface, '0.0.1') do
      action(:foo) { when_invoked { |options| "invoked the method" } }
    end

    expect(face.foo).to eq("invoked the method")
  end

  it "should require a block" do
    expect {
      Puppet::Interface::ActionBuilder.build(nil, :foo)
    }.to raise_error("Action :foo must specify a block")
  end

  it "should require an invocation block" do
    expect {
      Puppet::Interface::ActionBuilder.build(face, :foo) {}
    }.to raise_error(/actions need to know what to do when_invoked; please add the block/)
  end

  describe "when handling options" do
    it "should have a #option DSL function" do
      method = nil
      Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        method = self.method(:option)
      end
      expect(method).to be_an_instance_of Method
    end

    it "should define an option without a block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        option "--bar"
      end
      expect(action).to be_option :bar
    end

    it "should accept an empty block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        option "--bar" do
          # This space left deliberately blank.
        end
      end
      expect(action).to be_option :bar
    end
  end

  context "inline documentation" do
    it "should set the summary" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        summary "this is some text"
      end
      expect(action.summary).to eq("this is some text")
    end
  end

  context "action defaulting" do
    it "should set the default to true" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        default
      end
      expect(action.default).to be_truthy
    end

    it "should not be default by, er, default. *cough*" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
      end
      expect(action.default).to be_falsey
    end
  end

  context "#when_rendering" do
    it "should fail if no rendering format is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering do true end
        end
      }.to raise_error ArgumentError, /must give a rendering format to when_rendering/
    end

    it "should fail if no block is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering :json
        end
      }.to raise_error ArgumentError, /must give a block to when_rendering/
    end

    it "should fail if the block takes no arguments" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering :json do true end
        end
      }.to raise_error ArgumentError,
        /the puppet_interface_actionbuilder face foo action takes .* not/
    end

    it "should fail if the when_rendering block takes a different number of arguments than when_invoked" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering :json do |a, b, c| true end
        end
      }.to raise_error ArgumentError,
        /the puppet_interface_actionbuilder face foo action takes .* not 3/
    end

    it "should fail if the block takes a variable number of arguments" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering :json do |*args| true end
        end
      }.to raise_error ArgumentError,
        /the puppet_interface_actionbuilder face foo action takes .* not/
    end

    it "should stash a rendering block" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        when_rendering :json do |a| true end
      end
      expect(action.when_rendering(:json)).to be_an_instance_of Method
    end

    it "should fail if you try to set the same rendering twice" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          when_rendering :json do |a| true end
          when_rendering :json do |a| true end
        end
      }.to raise_error ArgumentError, /You can't define a rendering method for json twice/
    end

    it "should work if you set two different renderings" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        when_rendering :json do |a| true end
        when_rendering :yaml do |a| true end
      end
      expect(action.when_rendering(:json)).to be_an_instance_of Method
      expect(action.when_rendering(:yaml)).to be_an_instance_of Method
    end

    it "should be bound to the face when called" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
        when_rendering :json do |a| self end
      end
      expect(action.when_rendering(:json).call(true)).to eq(face)
    end
  end

  context "#render_as" do
    it "should default to nil (eg: based on context)" do
      action = Puppet::Interface::ActionBuilder.build(face, :foo) do
        when_invoked do |options| true end
      end
      expect(action.render_as).to be_nil
    end

    it "should fail if not rendering format is given" do
      expect {
        Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          render_as
        end
      }.to raise_error ArgumentError, /must give a rendering format to render_as/
    end

    Puppet::Network::FormatHandler.formats.each do |name|
      it "should accept #{name.inspect} format" do
        action = Puppet::Interface::ActionBuilder.build(face, :foo) do
          when_invoked do |options| true end
          render_as name
        end
        expect(action.render_as).to eq(name)
      end
    end

    [:if_you_define_this_format_you_frighten_me, "json", 12].each do |input|
      it "should fail if given #{input.inspect}" do
        expect {
          Puppet::Interface::ActionBuilder.build(face, :foo) do
            when_invoked do |options| true end
            render_as input
          end
        }.to raise_error ArgumentError, /#{input.inspect} is not a valid rendering format/
      end
    end
  end
end
