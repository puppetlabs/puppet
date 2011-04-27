#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/interface/action'

describe Puppet::Interface::Action do
  describe "when validating the action name" do
    [nil, '', 'foo bar', '-foobar'].each do |input|
      it "should treat #{input.inspect} as an invalid name" do
        expect { Puppet::Interface::Action.new(nil, input) }.
          should raise_error(/is an invalid action name/)
      end
    end
  end

  describe "#when_invoked=" do
    it "should fail if the block has arity 0" do
      pending "Ruby 1.8 (painfully) treats argument-free blocks as arity -1" if
        RUBY_VERSION =~ /^1\.8/

      expect {
        Puppet::Interface.new(:action_when_invoked, '1.0.0') do
          action :foo do
            when_invoked do
            end
          end
        end
      }.to raise_error ArgumentError, /foobra/
    end

    it "should work with arity 1 blocks" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one| }
        end
      end
      # -1, because we use option defaulting. :(
      face.method(:foo).arity.should == -1
    end

    it "should work with arity 2 blocks" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one, two| }
        end
      end
      # -2, because we use option defaulting. :(
      face.method(:foo).arity.should == -2
    end

    it "should work with arity 1 blocks that collect arguments" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|*one| }
        end
      end
      # -1, because we use only varargs
      face.method(:foo).arity.should == -1
    end

    it "should work with arity 2 blocks that collect arguments" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one, *two| }
        end
      end
      # -2, because we take one mandatory argument, and one varargs
      face.method(:foo).arity.should == -2
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

        action(:noopts) do
          # no options declared
        end
      end
    end

    subject { action = face.action(:new_action) { } }

    it 'should add the options from the specified action' do
      subject.inherit_options_from(foo = face.get_action(:foo))
      subject.options.should == foo.options
    end

    it 'should not die when the specified action has no options' do
      original_options = subject.options
      subject.inherit_options_from(face.get_action(:noopts))
      subject.options.should == original_options
    end

    it 'should add the options from multiple actions' do
      subject.inherit_options_from(foo = face.get_action(:foo))
      subject.inherit_options_from(bar = face.get_action(:bar))
      subject.options.should == (foo.options + bar.options).uniq.sort
    end

    it 'should not inherit face options' do
      subject.expects(:add_option)
      subject.expects(:add_option).with(face.get_option(:w)).never
      subject.inherit_options_from(face.get_action(:bar))
    end

    it 'should raise an error if inheritance would duplicate options' do
      subject.inherit_options_from(face.get_action(:bar))
      expect { subject.inherit_options_from(face.get_action(:baz)) }.to raise_error
    end
  end

  describe "when invoking" do
    it "should be able to call other actions on the same object" do
      face = Puppet::Interface.new(:my_face, '0.0.1') do
        action(:foo) do
          when_invoked { 25 }
        end

        action(:bar) do
          when_invoked { "the value of foo is '#{foo}'" }
        end
      end
      face.foo.should == 25
      face.bar.should == "the value of foo is '25'"
    end

    # bar is a class action calling a class action
    # quux is a class action calling an instance action
    # baz is an instance action calling a class action
    # qux is an instance action calling an instance action
    it "should be able to call other actions on the same object when defined on a class" do
      class Puppet::Interface::MyInterfaceBaseClass < Puppet::Interface
        action(:foo) do
          when_invoked { 25 }
        end

        action(:bar) do
          when_invoked { "the value of foo is '#{foo}'" }
        end

        action(:quux) do
          when_invoked { "qux told me #{qux}" }
        end
      end

      face = Puppet::Interface::MyInterfaceBaseClass.new(:my_inherited_face, '0.0.1') do
        action(:baz) do
          when_invoked { "the value of foo in baz is '#{foo}'" }
        end

        action(:qux) do
          when_invoked { baz }
        end
      end
      face.foo.should  == 25
      face.bar.should  == "the value of foo is '25'"
      face.quux.should == "qux told me the value of foo in baz is '25'"
      face.baz.should  == "the value of foo in baz is '25'"
      face.qux.should  == "the value of foo in baz is '25'"
    end

    context "when calling the Ruby API" do
      let :face do
        Puppet::Interface.new(:ruby_api, '1.0.0') do
          action :bar do
            when_invoked do |*args|
              args.last
            end
          end
        end
      end

      it "should work when no options are supplied" do
        options = face.bar
        options.should == {}
      end

      it "should work when options are supplied" do
        options = face.bar(:bar => "beer")
        options.should == { :bar => "beer" }
      end

      it "should call #validate_args on the action when invoked" do
        face.get_action(:bar).expects(:validate_args).with([1, :two, 'three', {}])
        face.bar 1, :two, 'three'
      end
    end
  end

  describe "with action-level options" do
    it "should support options with an empty block" do
      face = Puppet::Interface.new(:action_level_options, '0.0.1') do
        action :foo do
          option "--bar" do
            # this line left deliberately blank
          end
        end
      end

      face.should_not be_option :bar
      face.get_action(:foo).should be_option :bar
    end

    it "should return only action level options when there are no face options" do
      face = Puppet::Interface.new(:action_level_options, '0.0.1') do
        action :foo do option "--bar" end
      end

      face.get_action(:foo).options.should =~ [:bar]
    end

    describe "with both face and action options" do
      let :face do
        Puppet::Interface.new(:action_level_options, '0.0.1') do
          action :foo do option "--bar" end
          action :baz do option "--bim" end
          option "--quux"
        end
      end

      it "should return combined face and action options" do
        face.get_action(:foo).options.should =~ [:bar, :quux]
      end

      it "should fetch options that the face inherited" do
        parent = Class.new(Puppet::Interface)
        parent.option "--foo"
        child = parent.new(:inherited_options, '0.0.1') do
          option "--bar"
          action :action do option "--baz" end
        end

        action = child.get_action(:action)
        action.should be

        [:baz, :bar, :foo].each do |name|
          action.get_option(name).should be_an_instance_of Puppet::Interface::Option
        end
      end

      it "should get an action option when asked" do
        face.get_action(:foo).get_option(:bar).
          should be_an_instance_of Puppet::Interface::Option
      end

      it "should get a face option when asked" do
        face.get_action(:foo).get_option(:quux).
          should be_an_instance_of Puppet::Interface::Option
      end

      it "should return options only for this action" do
        face.get_action(:baz).options.should =~ [:bim, :quux]
      end
    end

    it_should_behave_like "things that declare options" do
      def add_options_to(&block)
        face = Puppet::Interface.new(:with_options, '0.0.1') do
          action(:foo, &block)
        end
        face.get_action(:foo)
      end
    end

    it "should fail when a face option duplicates an action option" do
      expect {
        Puppet::Interface.new(:action_level_options, '0.0.1') do
          option "--foo"
          action :bar do option "--foo" end
        end
      }.should raise_error ArgumentError, /Option foo conflicts with existing option foo/i
    end

    it "should fail when a required action option is not provided" do
      face = Puppet::Interface.new(:required_action_option, '0.0.1') do
        action(:bar) do
          option('--foo') { required }
          when_invoked { }
        end
      end
      expect { face.bar }.to raise_error ArgumentError, /missing required options \(foo\)/
    end

    it "should fail when a required face option is not provided" do
      face = Puppet::Interface.new(:required_face_option, '0.0.1') do
        option('--foo') { required }
        action(:bar) { when_invoked { } }
      end
      expect { face.bar }.to raise_error ArgumentError, /missing required options \(foo\)/
    end
  end

  context "with action decorators" do
    context "local only" do
      let :face do
        Puppet::Interface.new(:action_decorators, '0.0.1') do
          action :bar do when_invoked do true end end
          def report(arg) end
        end
      end

      it "should call action before decorators" do
        face.action(:baz) do
          option "--baz" do
            before_action do |action, args, options|
              report(:action_option)
            end
          end
          when_invoked do true end
        end

        face.expects(:report).with(:action_option)
        face.baz :baz => true
      end

      it "should call action after decorators" do
        face.action(:baz) do
          option "--baz" do
            after_action do |action, args, options|
              report(:action_option)
            end
          end
          when_invoked do true end
        end

        face.expects(:report).with(:action_option)
        face.baz :baz => true
      end

      it "should call local before decorators" do
        face.option "--foo FOO" do
          before_action do |action, args, options|
            report(:before)
          end
        end
        face.expects(:report).with(:before)
        face.bar({:foo => 12})
      end

      it "should call local after decorators" do
        face.option "--foo FOO" do
          after_action do |action, args, options| report(:after) end
        end
        face.expects(:report).with(:after)
        face.bar({:foo => 12})
      end

      context "with inactive decorators" do
        it "should not invoke a decorator if the options are empty" do
          face.option "--foo FOO" do
            before_action do |action, args, options|
              report :before_action
            end
          end
          face.expects(:report).never # I am testing the negative.
          face.bar
        end

        context "with some decorators only" do
          before :each do
            face.option "--foo" do
              before_action do |action, args, options| report :foo end
            end
            face.option "--bar" do
              before_action do |action, args, options| report :bar end
            end
          end

          it "should work with the foo option" do
            face.expects(:report).with(:foo)
            face.bar(:foo => true)
          end

          it "should work with the bar option" do
            face.expects(:report).with(:bar)
            face.bar(:bar => true)
          end

          it "should work with both options" do
            face.expects(:report).with(:foo)
            face.expects(:report).with(:bar)
            face.bar(:foo => true, :bar => true)
          end
        end
      end
    end

    context "with inherited decorators" do
      let :parent do
        parent = Class.new(Puppet::Interface)
        parent.script :on_parent do :on_parent end
        parent.define_method :report do |arg| arg end
        parent
      end

      let :child do
        child = parent.new(:inherited_decorators, '0.0.1') do
          script :on_child do :on_child end
        end
      end

      context "with a child decorator" do
        subject do
          child.option "--foo FOO" do
            before_action do |action, args, options|
              report(:child_before)
            end
          end
          child.expects(:report).with(:child_before)
          child
        end

        it "child actions should invoke the decorator" do
          subject.on_child({:foo => true, :bar => true}).should == :on_child
        end

        it "parent actions should invoke the decorator" do
          subject.on_parent({:foo => true, :bar => true}).should == :on_parent
        end
      end

      context "with a parent decorator" do
        subject do
          parent.option "--foo FOO" do
            before_action do |action, args, options|
              report(:parent_before)
            end
          end
          child.expects(:report).with(:parent_before)
          child
        end

        it "child actions should invoke the decorator" do
          subject.on_child({:foo => true, :bar => true}).should == :on_child
        end

        it "parent actions should invoke the decorator" do
          subject.on_parent({:foo => true, :bar => true}).should == :on_parent
        end
      end

      context "with child and parent decorators" do
        subject do
          parent.option "--foo FOO" do
            before_action { |action, args, options| report(:parent_before) }
            after_action  { |action, args, options| report(:parent_after)  }
          end
          child.option "--bar BAR" do
            before_action { |action, args, options| report(:child_before) }
            after_action  { |action, args, options| report(:child_after)  }
          end

          child.expects(:report).with(:child_before)
          child.expects(:report).with(:parent_before)
          child.expects(:report).with(:parent_after)
          child.expects(:report).with(:child_after)

          child
        end

        it "child actions should invoke all the decorator" do
          subject.on_child({:foo => true, :bar => true}).should == :on_child
        end

        it "parent actions should invoke all the decorator" do
          subject.on_parent({:foo => true, :bar => true}).should == :on_parent
        end
      end
    end
  end

  it_should_behave_like "documentation on faces" do
    subject do
      face = Puppet::Interface.new(:action_documentation, '0.0.1') do
        action :documentation do end
      end
      face.get_action(:documentation)
    end
  end

  context "#when_rendering" do
    it "should fail if no type is given when_rendering"
    it "should accept a when_rendering block"
    it "should accept multiple when_rendering blocks"
    it "should fail if when_rendering gets a non-symbol identifier"
    it "should fail if a second block is given for the same type"
    it "should return the block if asked"
  end
end
