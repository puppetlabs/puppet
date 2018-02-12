#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/interface'

describe Puppet::Interface::Action do
  describe "when validating the action name" do
    [nil, '', 'foo bar', '-foobar'].each do |input|
      it "should treat #{input.inspect} as an invalid name" do
        expect {
          Puppet::Interface::Action.new(nil, input)
        }.to raise_error(/is an invalid action name/)
      end
    end
  end

  describe "#when_invoked=" do
    it "should fail if the block has arity 0" do
      expect {
        Puppet::Interface.new(:action_when_invoked, '1.0.0') do
          action :foo do
            when_invoked { }
          end
        end
      }.to raise_error ArgumentError, /foo/
    end

    it "should work with arity 1 blocks" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one| }
        end
      end
      # -1, because we use option defaulting. :(
      expect(face.method(:foo).arity).to eq(-1)
    end

    it "should work with arity 2 blocks" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one, two| }
        end
      end
      # -2, because we use option defaulting. :(
      expect(face.method(:foo).arity).to eq(-2)
    end

    it "should work with arity 1 blocks that collect arguments" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|*one| }
        end
      end
      # -1, because we use only varargs
      expect(face.method(:foo).arity).to eq(-1)
    end

    it "should work with arity 2 blocks that collect arguments" do
      face = Puppet::Interface.new(:action_when_invoked, '1.0.0') do
        action :foo do
          when_invoked {|one, *two| }
        end
      end
      # -2, because we take one mandatory argument, and one varargs
      expect(face.method(:foo).arity).to eq(-2)
    end
  end

  describe "when invoking" do
    it "should be able to call other actions on the same object" do
      face = Puppet::Interface.new(:my_face, '0.0.1') do
        action(:foo) do
          when_invoked { |options| 25 }
        end

        action(:bar) do
          when_invoked { |options| "the value of foo is '#{foo}'" }
        end
      end
      expect(face.foo).to eq(25)
      expect(face.bar).to eq("the value of foo is '25'")
    end

    # bar is a class action calling a class action
    # quux is a class action calling an instance action
    # baz is an instance action calling a class action
    # qux is an instance action calling an instance action
    it "should be able to call other actions on the same object when defined on a class" do
      class Puppet::Interface::MyInterfaceBaseClass < Puppet::Interface
        action(:foo) do
          when_invoked { |options| 25 }
        end

        action(:bar) do
          when_invoked { |options| "the value of foo is '#{foo}'" }
        end

        action(:quux) do
          when_invoked { |options| "qux told me #{qux}" }
        end
      end

      face = Puppet::Interface::MyInterfaceBaseClass.new(:my_inherited_face, '0.0.1') do
        action(:baz) do
          when_invoked { |options| "the value of foo in baz is '#{foo}'" }
        end

        action(:qux) do
          when_invoked { |options| baz }
        end
      end
      expect(face.foo).to  eq(25)
      expect(face.bar).to  eq("the value of foo is '25'")
      expect(face.quux).to eq("qux told me the value of foo in baz is '25'")
      expect(face.baz).to  eq("the value of foo in baz is '25'")
      expect(face.qux).to  eq("the value of foo in baz is '25'")
    end

    context "when calling the Ruby API" do
      let :face do
        Puppet::Interface.new(:ruby_api, '1.0.0') do
          action :bar do
            option "--bar"
            when_invoked do |*args|
              args.last
            end
          end
        end
      end

      it "should work when no options are supplied" do
        options = face.bar
        expect(options).to eq({})
      end

      it "should work when options are supplied" do
        options = face.bar(:bar => "beer")
        expect(options).to eq({ :bar => "beer" })
      end

      it "should call #validate_and_clean on the action when invoked" do
        face.get_action(:bar).expects(:validate_and_clean).with({}).returns({})
        face.bar 1, :two, 'three'
      end
    end
  end

  describe "with action-level options" do
    it "should support options with an empty block" do
      face = Puppet::Interface.new(:action_level_options, '0.0.1') do
        action :foo do
          when_invoked do |options| true end
          option "--bar" do
            # this line left deliberately blank
          end
        end
      end

      expect(face).not_to be_option :bar
      expect(face.get_action(:foo)).to be_option :bar
    end

    it "should return only action level options when there are no face options" do
      face = Puppet::Interface.new(:action_level_options, '0.0.1') do
        action :foo do
          when_invoked do |options| true end
          option "--bar"
        end
      end

      expect(face.get_action(:foo).options).to match_array([:bar])
    end

    describe "option aliases" do
      let :option do action.get_option :bar end
      let :action do face.get_action :foo end
      let :face do
        Puppet::Interface.new(:action_level_options, '0.0.1') do
          action :foo do
            when_invoked do |options| options end
            option "--bar", "--foo", "-b"
          end
        end
      end

      it "should only list options and not aliases" do
        expect(action.options).to match_array([:bar])
      end

      it "should use the canonical option name when passed aliases" do
        name = option.name
        option.aliases.each do |input|
          expect(face.foo(input => 1)).to eq({ name => 1 })
        end
      end
    end

    describe "with both face and action options" do
      let :face do
        Puppet::Interface.new(:action_level_options, '0.0.1') do
          action :foo do when_invoked do |options| true end ; option "--bar" end
          action :baz do when_invoked do |options| true end ; option "--bim" end
          option "--quux"
        end
      end

      it "should return combined face and action options" do
        expect(face.get_action(:foo).options).to match_array([:bar, :quux])
      end

      it "should fetch options that the face inherited" do
        parent = Class.new(Puppet::Interface)
        parent.option "--foo"
        child = parent.new(:inherited_options, '0.0.1') do
          option "--bar"
          action :action do
            when_invoked do |options| true end
            option "--baz"
          end
        end

        action = child.get_action(:action)
        expect(action).to be

        [:baz, :bar, :foo].each do |name|
          expect(action.get_option(name)).to be_an_instance_of Puppet::Interface::Option
        end
      end

      it "should get an action option when asked" do
        expect(face.get_action(:foo).get_option(:bar)).
          to be_an_instance_of Puppet::Interface::Option
      end

      it "should get a face option when asked" do
        expect(face.get_action(:foo).get_option(:quux)).
          to be_an_instance_of Puppet::Interface::Option
      end

      it "should return options only for this action" do
        expect(face.get_action(:baz).options).to match_array([:bim, :quux])
      end
    end

    it_should_behave_like "things that declare options" do
      def add_options_to(&block)
        face = Puppet::Interface.new(:with_options, '0.0.1') do
          action(:foo) do
            when_invoked do |options| true end
            self.instance_eval(&block)
          end
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
      }.to raise_error ArgumentError, /Option foo conflicts with existing option foo/i
    end

    it "should fail when a required action option is not provided" do
      face = Puppet::Interface.new(:required_action_option, '0.0.1') do
        action(:bar) do
          option('--foo') { required }
          when_invoked {|options| }
        end
      end
      expect { face.bar }.to raise_error ArgumentError, /The following options are required: foo/
    end

    it "should fail when a required face option is not provided" do
      face = Puppet::Interface.new(:required_face_option, '0.0.1') do
        option('--foo') { required }
        action(:bar) { when_invoked {|options| } }
      end
      expect { face.bar }.to raise_error ArgumentError, /The following options are required: foo/
    end
  end

  context "with decorators" do
    context "declared locally" do
      let :face do
        Puppet::Interface.new(:action_decorators, '0.0.1') do
          action :bar do when_invoked do |options| true end end
          def reported; @reported; end
          def report(arg)
            (@reported ||= []) << arg
          end
        end
      end

      it "should execute before advice on action options in declaration order" do
        face.action(:boo) do
          option("--foo")        { before_action { |_,_,_| report :foo  } }
          option("--bar", '-b')  { before_action { |_,_,_| report :bar  } }
          option("-q", "--quux") { before_action { |_,_,_| report :quux } }
          option("-f")           { before_action { |_,_,_| report :f    } }
          option("--baz")        { before_action { |_,_,_| report :baz  } }
          when_invoked {|options| }
        end

        face.boo :foo => 1, :bar => 1, :quux => 1, :f => 1, :baz => 1
        expect(face.reported).to eq([ :foo, :bar, :quux, :f, :baz ])
      end

      it "should execute after advice on action options in declaration order" do
        face.action(:boo) do
          option("--foo")        { after_action { |_,_,_| report :foo  } }
          option("--bar", '-b')  { after_action { |_,_,_| report :bar  } }
          option("-q", "--quux") { after_action { |_,_,_| report :quux } }
          option("-f")           { after_action { |_,_,_| report :f    } }
          option("--baz")        { after_action { |_,_,_| report :baz  } }
          when_invoked {|options| }
        end

        face.boo :foo => 1, :bar => 1, :quux => 1, :f => 1, :baz => 1
        expect(face.reported).to eq([ :foo, :bar, :quux, :f, :baz ].reverse)
      end

      it "should execute before advice on face options in declaration order" do
        face.instance_eval do
          option("--foo")        { before_action { |_,_,_| report :foo  } }
          option("--bar", '-b')  { before_action { |_,_,_| report :bar  } }
          option("-q", "--quux") { before_action { |_,_,_| report :quux } }
          option("-f")           { before_action { |_,_,_| report :f    } }
          option("--baz")        { before_action { |_,_,_| report :baz  } }
        end
        face.action(:boo) { when_invoked { |options| } }

        face.boo :foo => 1, :bar => 1, :quux => 1, :f => 1, :baz => 1
        expect(face.reported).to eq([ :foo, :bar, :quux, :f, :baz ])
      end

      it "should execute after advice on face options in declaration order" do
        face.instance_eval do
          option("--foo")        { after_action { |_,_,_| report :foo  } }
          option("--bar", '-b')  { after_action { |_,_,_| report :bar  } }
          option("-q", "--quux") { after_action { |_,_,_| report :quux } }
          option("-f")           { after_action { |_,_,_| report :f    } }
          option("--baz")        { after_action { |_,_,_| report :baz  } }
        end
        face.action(:boo) { when_invoked { |options| } }

        face.boo :foo => 1, :bar => 1, :quux => 1, :f => 1, :baz => 1
        expect(face.reported).to eq([ :foo, :bar, :quux, :f, :baz ].reverse)
      end

      it "should execute before advice on face options before action options" do
        face.instance_eval do
          option("--face-foo")        { before_action { |_,_,_| report :face_foo  } }
          option("--face-bar", '-r')  { before_action { |_,_,_| report :face_bar  } }
          action(:boo) do
            option("--action-foo")        { before_action { |_,_,_| report :action_foo  } }
            option("--action-bar", '-b')  { before_action { |_,_,_| report :action_bar  } }
            option("-q", "--action-quux") { before_action { |_,_,_| report :action_quux } }
            option("-a")                  { before_action { |_,_,_| report :a           } }
            option("--action-baz")        { before_action { |_,_,_| report :action_baz  } }
            when_invoked {|options| }
          end
          option("-u", "--face-quux") { before_action { |_,_,_| report :face_quux } }
          option("-f")                { before_action { |_,_,_| report :f         } }
          option("--face-baz")        { before_action { |_,_,_| report :face_baz  } }
        end

        expected_calls = [ :face_foo, :face_bar, :face_quux, :f, :face_baz,
                           :action_foo, :action_bar, :action_quux, :a, :action_baz ]
        face.boo Hash[ *expected_calls.zip([]).flatten ]
        expect(face.reported).to eq(expected_calls)
      end

      it "should execute after advice on face options in declaration order" do
        face.instance_eval do
          option("--face-foo")        { after_action { |_,_,_| report :face_foo  } }
          option("--face-bar", '-r')  { after_action { |_,_,_| report :face_bar  } }
          action(:boo) do
            option("--action-foo")        { after_action { |_,_,_| report :action_foo  } }
            option("--action-bar", '-b')  { after_action { |_,_,_| report :action_bar  } }
            option("-q", "--action-quux") { after_action { |_,_,_| report :action_quux } }
            option("-a")                  { after_action { |_,_,_| report :a           } }
            option("--action-baz")        { after_action { |_,_,_| report :action_baz  } }
            when_invoked {|options| }
          end
          option("-u", "--face-quux") { after_action { |_,_,_| report :face_quux } }
          option("-f")                { after_action { |_,_,_| report :f         } }
          option("--face-baz")        { after_action { |_,_,_| report :face_baz  } }
        end

        expected_calls = [ :face_foo, :face_bar, :face_quux, :f, :face_baz,
                           :action_foo, :action_bar, :action_quux, :a, :action_baz ]
        face.boo Hash[ *expected_calls.zip([]).flatten ]
        expect(face.reported).to eq(expected_calls.reverse)
      end

      it "should not invoke a decorator if the options are empty" do
        face.option("--foo FOO") { before_action { |_,_,_| report :before_action } }
        face.expects(:report).never
        face.bar
      end

      context "passing a subset of the options" do
        before :each do
          face.option("--foo") { before_action { |_,_,_| report :foo } }
          face.option("--bar") { before_action { |_,_,_| report :bar } }
        end

        it "should invoke only foo's advice when passed only 'foo'" do
          face.bar(:foo => true)
          expect(face.reported).to eq([ :foo ])
        end

        it "should invoke only bar's advice when passed only 'bar'" do
          face.bar(:bar => true)
          expect(face.reported).to eq([ :bar ])
        end

        it "should invoke advice for all passed options" do
          face.bar(:foo => true, :bar => true)
          expect(face.reported).to eq([ :foo, :bar ])
        end
      end
    end

    context "and inheritance" do
      let :parent do
        Class.new(Puppet::Interface) do
          action(:on_parent) { when_invoked { |options| :on_parent } }

          def reported; @reported; end
          def report(arg)
            (@reported ||= []) << arg
          end
        end
      end

      let :child do
        parent.new(:inherited_decorators, '0.0.1') do
          action(:on_child) { when_invoked { |options| :on_child } }
        end
      end

      context "locally declared face options" do
        subject do
          child.option("--foo=") { before_action { |_,_,_| report :child_before } }
          child
        end

        it "should be invoked when calling a child action" do
          expect(subject.on_child(:foo => true)).to eq(:on_child)
          expect(subject.reported).to eq([ :child_before ])
        end

        it "should be invoked when calling a parent action" do
          expect(subject.on_parent(:foo => true)).to eq(:on_parent)
          expect(subject.reported).to eq([ :child_before ])
        end
      end

      context "inherited face option decorators" do
        subject do
          parent.option("--foo=") { before_action { |_,_,_| report :parent_before } }
          child
        end

        it "should be invoked when calling a child action" do
          expect(subject.on_child(:foo => true)).to eq(:on_child)
          expect(subject.reported).to eq([ :parent_before ])
        end

        it "should be invoked when calling a parent action" do
          expect(subject.on_parent(:foo => true)).to eq(:on_parent)
          expect(subject.reported).to eq([ :parent_before ])
        end
      end

      context "with both inherited and local face options" do
        # Decorations should be invoked in declaration order, according to
        # inheritance (e.g. parent class options should be handled before
        # subclass options).
        subject do
          child.option "-c" do
            before_action { |action, args, options| report :c_before }
            after_action  { |action, args, options| report :c_after  }
          end

          parent.option "-a" do
            before_action { |action, args, options| report :a_before }
            after_action  { |action, args, options| report :a_after  }
          end

          child.option "-d" do
            before_action { |action, args, options| report :d_before }
            after_action  { |action, args, options| report :d_after  }
          end

          parent.option "-b" do
            before_action { |action, args, options| report :b_before }
            after_action  { |action, args, options| report :b_after  }
          end

          child.action(:decorations) { when_invoked {  |options| report :invoked } }

          child
        end

        it "should invoke all decorations when calling a child action" do
          subject.decorations(:a => 1, :b => 1, :c => 1, :d => 1)
          expect(subject.reported).to eq([
            :a_before, :b_before, :c_before, :d_before,
            :invoked,
            :d_after, :c_after, :b_after, :a_after
          ])
        end

        it "should invoke all decorations when calling a parent action" do
          subject.decorations(:a => 1, :b => 1, :c => 1, :d => 1)
          expect(subject.reported).to eq([
            :a_before, :b_before, :c_before, :d_before,
            :invoked,
            :d_after, :c_after, :b_after, :a_after
          ])
        end
      end
    end
  end

  it_should_behave_like "documentation on faces" do
    subject do
      face = Puppet::Interface.new(:action_documentation, '0.0.1') do
        action :documentation do
          when_invoked do |options| true end
        end
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

  context "#validate_and_clean" do
    subject do
      Puppet::Interface.new(:validate_args, '1.0.0') do
        action(:test) { when_invoked { |options| options } }
      end
    end

    it "should fail if a required option is not passed" do
      subject.option "--foo" do required end
      expect { subject.test }.to raise_error ArgumentError, /options are required/
    end

    it "should fail if two aliases to one option are passed" do
      subject.option "--foo", "-f"
      expect { subject.test :foo => true, :f => true }.
        to raise_error ArgumentError, /Multiple aliases for the same option/
    end

    it "should fail if an unknown option is passed" do
      expect { subject.test :unknown => true }.
        to raise_error ArgumentError, /Unknown options passed: unknown/
    end

    it "should report all the unknown options passed" do
      expect { subject.test :unknown => true, :unseen => false }.
        to raise_error ArgumentError, /Unknown options passed: unknown, unseen/
    end

    it "should accept 'global' options from settings" do
      expect {
        expect(subject.test(:certname => "true")).to eq({ :certname => "true" })
      }.not_to raise_error
    end
  end

  context "default option values" do
    subject do
      Puppet::Interface.new(:default_option_values, '1.0.0') do
        action :foo do
          option "--foo" do end
          option "--bar" do end
          when_invoked do |options| options end
        end
      end
    end

    let :action do subject.get_action :foo end
    let :option do action.get_option :foo end

    it "should not add options without defaults" do
      expect(subject.foo).to eq({})
    end

    it "should not add options without defaults, if options are given" do
      expect(subject.foo(:bar => 1)).to eq({ :bar => 1 })
    end

    it "should add the option default value when set" do
      option.default = proc { 12 }
      expect(subject.foo).to eq({ :foo => 12 })
    end

    it "should add the option default value when set, if other options are given" do
      option.default = proc { 12 }
      expect(subject.foo(:bar => 1)).to eq({ :foo => 12, :bar => 1 })
    end

    it "should invoke the same default proc every time called" do
      option.default = proc { @foo ||= {} }
      expect(subject.foo[:foo].object_id).to eq(subject.foo[:foo].object_id)
    end

    [nil, 0, 1, true, false, {}, []].each do |input|
      it "should not override a passed option (#{input.inspect})" do
        option.default = proc { :fail }
        expect(subject.foo(:foo => input)).to eq({ :foo => input })
      end
    end
  end

  context "runtime manipulations" do
    subject do
      Puppet::Interface.new(:runtime_manipulations, '1.0.0') do
        action :foo do
          when_invoked do |options| options end
        end
      end
    end

    let :action do subject.get_action :foo end

    it "should be the face default action if default is set true" do
      expect(subject.get_default_action).to be_nil
      action.default = true
      expect(subject.get_default_action).to eq(action)
    end
  end

  context "when deprecating a face action" do
    let :face do
      Puppet::Interface.new(:foo, '1.0.0') do
        action :bar do
          option "--bar"
          when_invoked do |options| options end
        end
      end
    end

    let :action do face.get_action :bar end

    describe "#deprecate" do
      it "should set the deprecated value to true" do
        expect(action).not_to be_deprecated
        action.deprecate
        expect(action).to be_deprecated
      end
    end

    describe "#deprecated?" do
      it "should return a nil (falsey) value by default" do
        expect(action.deprecated?).to be_falsey
      end

      it "should return true if the action has been deprecated" do
        expect(action).not_to be_deprecated
        action.deprecate
        expect(action).to be_deprecated
      end
    end
  end
end
