#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet_spec/compiler'
require 'puppet_spec/scope'

describe Puppet::Parser::Scope do
  include PuppetSpec::Scope

  before :each do
    @scope = Puppet::Parser::Scope.new(
      Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    )
    @scope.source = Puppet::Resource::Type.new(:node, :foo)
    @topscope = @scope.compiler.topscope
    @scope.parent = @topscope
  end

  describe "create_test_scope_for_node" do
    let(:node_name) { "node_name_foo" }
    let(:scope) { create_test_scope_for_node(node_name) }

    it "should be a kind of Scope" do
      scope.should be_a_kind_of(Puppet::Parser::Scope)
    end
    it "should set the source to a node resource" do
      scope.source.should be_a_kind_of(Puppet::Resource::Type)
    end
    it "should have a compiler" do
      scope.compiler.should be_a_kind_of(Puppet::Parser::Compiler)
    end
    it "should set the parent to the compiler topscope" do
      scope.parent.should be(scope.compiler.topscope)
    end
  end

  it "should return a scope for use in a test harness" do
    create_test_scope_for_node("node_name_foo").should be_a_kind_of(Puppet::Parser::Scope)
  end

  it "should be able to retrieve class scopes by name" do
    @scope.class_set "myname", "myscope"
    @scope.class_scope("myname").should == "myscope"
  end

  it "should be able to retrieve class scopes by object" do
    klass = mock 'ast_class'
    klass.expects(:name).returns("myname")
    @scope.class_set "myname", "myscope"
    @scope.class_scope(klass).should == "myscope"
  end

  it "should be able to retrieve its parent module name from the source of its parent type" do
    @topscope.source = Puppet::Resource::Type.new(:hostclass, :foo, :module_name => "foo")

    @scope.parent_module_name.should == "foo"
  end

  it "should return a nil parent module name if it has no parent" do
    @topscope.parent_module_name.should be_nil
  end

  it "should return a nil parent module name if its parent has no source" do
    @scope.parent_module_name.should be_nil
  end

  it "should get its environment from its compiler" do
    env = Puppet::Node::Environment.create(:testing, [])
    compiler = stub 'compiler', :environment => env, :is_a? => true
    scope = Puppet::Parser::Scope.new(compiler)
    scope.environment.should equal(env)
  end

  it "should fail if no compiler is supplied" do
    expect {
      Puppet::Parser::Scope.new
    }.to raise_error(ArgumentError, /wrong number of arguments/)
  end

  it "should fail if something that isn't a compiler is supplied" do
    expect {
      Puppet::Parser::Scope.new(:compiler => true)
    }.to raise_error(Puppet::DevError, /you must pass a compiler instance/)
  end

  it "should use the resource type collection helper to find its known resource types" do
    Puppet::Parser::Scope.ancestors.should include(Puppet::Resource::TypeCollectionHelper)
  end

  describe "when custom functions are called" do
    let(:env) { Puppet::Node::Environment.create(:testing, []) }
    let(:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new('foo', :environment => env)) }
    let(:scope) { Puppet::Parser::Scope.new(compiler) }

    it "calls methods prefixed with function_ as custom functions" do
      scope.function_sprintf(["%b", 123]).should == "1111011"
    end

    it "raises an error when arguments are not passed in an Array" do
      expect do
        scope.function_sprintf("%b", 123)
      end.to raise_error ArgumentError, /custom functions must be called with a single array that contains the arguments/
    end

    it "raises an error on subsequent calls when arguments are not passed in an Array" do
      scope.function_sprintf(["first call"])

      expect do
        scope.function_sprintf("%b", 123)
      end.to raise_error ArgumentError, /custom functions must be called with a single array that contains the arguments/
    end

    it "raises NoMethodError when the not prefixed" do
      expect { scope.sprintf(["%b", 123]) }.to raise_error(NoMethodError)
    end

    it "raises NoMethodError when prefixed with function_ but it doesn't exist" do
      expect { scope.function_fake_bs(['cows']) }.to raise_error(NoMethodError)
    end
  end

  describe "when initializing" do
    it "should extend itself with its environment's Functions module as well as the default" do
      env = Puppet::Node::Environment.create(:myenv, [])
      root = Puppet.lookup(:root_environment)
      compiler = stub 'compiler', :environment => env, :is_a? => true

      scope = Puppet::Parser::Scope.new(compiler)
      scope.singleton_class.ancestors.should be_include(Puppet::Parser::Functions.environment_module(env))
      scope.singleton_class.ancestors.should be_include(Puppet::Parser::Functions.environment_module(root))
    end

    it "should extend itself with the default Functions module if its environment is the default" do
      root     = Puppet.lookup(:root_environment)
      node     = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      scope    = Puppet::Parser::Scope.new(compiler)
      scope.singleton_class.ancestors.should be_include(Puppet::Parser::Functions.environment_module(root))
    end
  end

  describe "when looking up a variable" do
    it "should support :lookupvar and :setvar for backward compatibility" do
      @scope.setvar("var", "yep")
      @scope.lookupvar("var").should == "yep"
    end

    it "should fail if invoked with a non-string name" do
      expect { @scope[:foo] }.to raise_error(Puppet::ParseError, /Scope variable name .* not a string/)
      expect { @scope[:foo] = 12 }.to raise_error(Puppet::ParseError, /Scope variable name .* not a string/)
    end

    it "should return nil for unset variables" do
      @scope["var"].should be_nil
    end

    it "should be able to look up values" do
      @scope["var"] = "yep"
      @scope["var"].should == "yep"
    end

    it "should be able to look up hashes" do
      @scope["var"] = {"a" => "b"}
      @scope["var"].should == {"a" => "b"}
    end

    it "should be able to look up variables in parent scopes" do
      @topscope["var"] = "parentval"
      @scope["var"].should == "parentval"
    end

    it "should prefer its own values to parent values" do
      @topscope["var"] = "parentval"
      @scope["var"] = "childval"
      @scope["var"].should == "childval"
    end

    it "should be able to detect when variables are set" do
      @scope["var"] = "childval"
      @scope.should be_include("var")
    end

    it "does not allow changing a set value" do
      @scope["var"] = "childval"
      expect {
        @scope["var"] = "change"
      }.to raise_error(Puppet::Error, "Cannot reassign variable var")
    end

    it "should be able to detect when variables are not set" do
      @scope.should_not be_include("var")
    end

    describe "and the variable is qualified" do
      before :each do
        @known_resource_types = @scope.known_resource_types

        node      = Puppet::Node.new('localhost')
        @compiler = Puppet::Parser::Compiler.new(node)
      end

      def newclass(name)
        @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
      end

      def create_class_scope(name)
        klass = newclass(name)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => Puppet::Parser::Scope.new(@compiler)))

        Puppet::Parser::Resource.new("class", name, :scope => @scope, :source => mock('source'), :catalog => catalog).evaluate

        @scope.class_scope(klass)
      end

      it "should be able to look up explicitly fully qualified variables from main" do
        Puppet.expects(:deprecation_warning).never
        other_scope = create_class_scope("")

        other_scope["othervar"] = "otherval"

        @scope["::othervar"].should == "otherval"
      end

      it "should be able to look up explicitly fully qualified variables from other scopes" do
        Puppet.expects(:deprecation_warning).never
        other_scope = create_class_scope("other")

        other_scope["var"] = "otherval"

        @scope["::other::var"].should == "otherval"
      end

      it "should be able to look up deeply qualified variables" do
        Puppet.expects(:deprecation_warning).never
        other_scope = create_class_scope("other::deep::klass")

        other_scope["var"] = "otherval"

        @scope["other::deep::klass::var"].should == "otherval"
      end

      it "should return nil for qualified variables that cannot be found in other classes" do
        other_scope = create_class_scope("other::deep::klass")

        @scope["other::deep::klass::var"].should be_nil
      end

      it "should warn and return nil for qualified variables whose classes have not been evaluated" do
        klass = newclass("other::deep::klass")
        @scope.expects(:warning)
        @scope["other::deep::klass::var"].should be_nil
      end

      it "should warn and return nil for qualified variables whose classes do not exist" do
        @scope.expects(:warning)
        @scope["other::deep::klass::var"].should be_nil
      end

      it "should return nil when asked for a non-string qualified variable from a class that does not exist" do
        @scope.stubs(:warning)
        @scope["other::deep::klass::var"].should be_nil
      end

      it "should return nil when asked for a non-string qualified variable from a class that has not been evaluated" do
        @scope.stubs(:warning)
        klass = newclass("other::deep::klass")
        @scope["other::deep::klass::var"].should be_nil
      end
    end

    context "and strict_variables is true" do
      before(:each) do
        Puppet[:strict_variables] = true
      end

      it "should raise an error when unknown variable is looked up" do
        expect { @scope['john_doe'] }.to raise_error(/Undefined variable/)
      end

      it "should raise an error when unknown qualified variable is looked up" do
        expect { @scope['nowhere::john_doe'] }.to raise_error(/Undefined variable/)
      end

      it "should not raise an error when built in variable is looked up" do
        expect { @scope['caller_module_name'] }.to_not raise_error
        expect { @scope['module_name'] }.to_not raise_error
      end
    end
  end

  describe "when variables are set with append=true" do
    it "should raise error if the variable is already defined in this scope" do
      @scope.setvar("var", "1", :append => false)
      expect {
        @scope.setvar("var", "1", :append => true)
      }.to raise_error(
        Puppet::ParseError,
        "Cannot append, variable var is defined in this scope"
      )
    end

    it "should lookup current variable value" do
      @scope.expects(:[]).with("var").returns("2")
      @scope.setvar("var", "1", :append => true)
    end

    it "should store the concatenated string '42'" do
      @topscope.setvar("var", "4", :append => false)
      @scope.setvar("var", "2", :append => true)
      @scope["var"].should == "42"
    end

    it "should store the concatenated array [4,2]" do
      @topscope.setvar("var", [4], :append => false)
      @scope.setvar("var", [2], :append => true)
      @scope["var"].should == [4,2]
    end

    it "should store the merged hash {a => b, c => d}" do
      @topscope.setvar("var", {"a" => "b"}, :append => false)
      @scope.setvar("var", {"c" => "d"}, :append => true)
      @scope["var"].should == {"a" => "b", "c" => "d"}
    end

    it "should raise an error when appending a hash with something other than another hash" do
      @topscope.setvar("var", {"a" => "b"}, :append => false)

      expect {
        @scope.setvar("var", "not a hash", :append => true)
      }.to raise_error(
        ArgumentError,
        "Trying to append to a hash with something which is not a hash is unsupported"
      )
    end
  end

  describe "when calling number?" do
    it "should return nil if called with anything not a number" do
      Puppet::Parser::Scope.number?([2]).should be_nil
    end

    it "should return a Fixnum for a Fixnum" do
      Puppet::Parser::Scope.number?(2).should be_an_instance_of(Fixnum)
    end

    it "should return a Float for a Float" do
      Puppet::Parser::Scope.number?(2.34).should be_an_instance_of(Float)
    end

    it "should return 234 for '234'" do
      Puppet::Parser::Scope.number?("234").should == 234
    end

    it "should return nil for 'not a number'" do
      Puppet::Parser::Scope.number?("not a number").should be_nil
    end

    it "should return 23.4 for '23.4'" do
      Puppet::Parser::Scope.number?("23.4").should == 23.4
    end

    it "should return 23.4e13 for '23.4e13'" do
      Puppet::Parser::Scope.number?("23.4e13").should == 23.4e13
    end

    it "should understand negative numbers" do
      Puppet::Parser::Scope.number?("-234").should == -234
    end

    it "should know how to convert exponential float numbers ala '23e13'" do
      Puppet::Parser::Scope.number?("23e13").should == 23e13
    end

    it "should understand hexadecimal numbers" do
      Puppet::Parser::Scope.number?("0x234").should == 0x234
    end

    it "should understand octal numbers" do
      Puppet::Parser::Scope.number?("0755").should == 0755
    end

    it "should return nil on malformed integers" do
      Puppet::Parser::Scope.number?("0.24.5").should be_nil
    end

    it "should convert strings with leading 0 to integer if they are not octal" do
      Puppet::Parser::Scope.number?("0788").should == 788
    end

    it "should convert strings of negative integers" do
      Puppet::Parser::Scope.number?("-0788").should == -788
    end

    it "should return nil on malformed hexadecimal numbers" do
      Puppet::Parser::Scope.number?("0x89g").should be_nil
    end
  end

  describe "when using ephemeral variables" do
    it "should store the variable value" do
#      @scope.setvar("1", :value, :ephemeral => true)
      @scope.set_match_data({1 => :value})
      @scope["1"].should == :value
    end

    it "should remove the variable value when unset_ephemeral_var(:all) is called" do
#      @scope.setvar("1", :value, :ephemeral => true)
      @scope.set_match_data({1 => :value})
      @scope.stubs(:parent).returns(nil)

      @scope.unset_ephemeral_var(:all)

      @scope["1"].should be_nil
    end

    it "should not remove classic variables when unset_ephemeral_var(:all) is called" do
      @scope['myvar'] = :value1
      @scope.set_match_data({1 => :value2})
      @scope.stubs(:parent).returns(nil)

      @scope.unset_ephemeral_var(:all)

      @scope["myvar"].should == :value1
    end

    it "should raise an error when setting numerical variable" do
      expect {
        @scope.setvar("1", :value3, :ephemeral => true)
      }.to raise_error(Puppet::ParseError, /Cannot assign to a numeric match result variable/)
    end

    describe "with more than one level" do
      it "should prefer latest ephemeral scopes" do
        @scope.set_match_data({0 => :earliest})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :latest})
        @scope["0"].should == :latest
      end

      it "should be able to report the current level" do
        @scope.ephemeral_level.should == 1
        @scope.new_ephemeral
        @scope.ephemeral_level.should == 2
      end

      it "should not check presence of an ephemeral variable accross multiple levels" do
        # This test was testing that scope actuallys screwed up - making values from earlier matches show as if they
        # where true for latest match - insanity !
        @scope.new_ephemeral
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        @scope.new_ephemeral
        @scope.include?("1").should be_false
      end

      it "should return false when an ephemeral variable doesn't exist in any ephemeral scope" do
        @scope.new_ephemeral
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        @scope.new_ephemeral
        @scope.include?("2").should be_false
      end

      it "should not get ephemeral values from earlier scope when not in later" do
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        @scope.include?("1").should be_false
      end

      describe "when calling unset_ephemeral_var with a level" do
        it "should remove ephemeral scopes up to this level" do
          @scope.set_match_data({1 => :value1})
          @scope.new_ephemeral
          @scope.set_match_data({1 => :value2})
          level = @scope.ephemeral_level()
          @scope.new_ephemeral
          @scope.set_match_data({1 => :value3})

          @scope.unset_ephemeral_var(level)

          @scope["1"].should == :value2
        end
      end
    end
  end

  context "when using ephemeral as local scope" do
    it "should store all variables in local scope" do
      @scope.new_ephemeral true
      @scope.setvar("apple", :fruit)
      @scope["apple"].should == :fruit
    end

    it "should remove all local scope variables on unset" do
      @scope.new_ephemeral true
      @scope.setvar("apple", :fruit)
      @scope["apple"].should == :fruit
      @scope.unset_ephemeral_var
      @scope["apple"].should == nil
    end
    it "should be created from a hash" do
      @scope.ephemeral_from({ "apple" => :fruit, "strawberry" => :berry})
      @scope["apple"].should == :fruit
      @scope["strawberry"].should == :berry
    end
  end

  describe "when setting ephemeral vars from matches" do
    before :each do
      @match = stub 'match', :is_a? => true
      @match.stubs(:[]).with(0).returns("this is a string")
      @match.stubs(:captures).returns([])
      @scope.stubs(:setvar)
    end

    it "should accept only MatchData" do
      expect {
        @scope.ephemeral_from("match")
      }.to raise_error(ArgumentError, /Invalid regex match data/)
    end

    it "should set $0 with the full match" do
      # This is an internal impl detail test
      @scope.expects(:new_match_scope).with { |*arg| arg[0][0] == "this is a string" }
      @scope.ephemeral_from(@match)
    end

    it "should set every capture as ephemeral var" do
      # This is an internal impl detail test
      @match.stubs(:[]).with(1).returns(:capture1)
      @match.stubs(:[]).with(2).returns(:capture2)
      @scope.expects(:new_match_scope).with { |*arg| arg[0][1] == :capture1 && arg[0][2] == :capture2 }

      @scope.ephemeral_from(@match)
    end

    it "should shadow previous match variables" do
      # This is an internal impl detail test
      @match.stubs(:[]).with(1).returns(:capture1)
      @match.stubs(:[]).with(2).returns(:capture2)

      @match2 = stub 'match', :is_a? => true
      @match2.stubs(:[]).with(1).returns(:capture2_1)
      @match2.stubs(:[]).with(2).returns(nil)
      @scope.ephemeral_from(@match)
      @scope.ephemeral_from(@match2)
      @scope.lookupvar('2').should == nil
    end

    it "should create a new ephemeral level" do
      level_before = @scope.ephemeral_level
      @scope.ephemeral_from(@match)
      expect(level_before < @scope.ephemeral_level)
    end
  end

  it "should use its namespaces to find hostclasses" do
    klass = @scope.known_resource_types.add Puppet::Resource::Type.new(:hostclass, "a::b::c")
    @scope.add_namespace "a::b"
    @scope.find_hostclass("c").should equal(klass)
  end

  it "should use its namespaces to find definitions" do
    define = @scope.known_resource_types.add Puppet::Resource::Type.new(:definition, "a::b::c")
    @scope.add_namespace "a::b"
    @scope.find_definition("c").should equal(define)
  end

  describe "when managing defaults" do
    it "should be able to set and lookup defaults" do
      param = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param)
      @scope.lookupdefaults(:mytype).should == {:myparam => param}
    end

    it "should fail if a default is already defined and a new default is being defined" do
      param = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param)
      expect {
        @scope.define_settings(:mytype, param)
      }.to raise_error(Puppet::ParseError, /Default already defined .* cannot redefine/)
    end

    it "should return multiple defaults at once" do
      param1 = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param1)
      param2 = Puppet::Parser::Resource::Param.new(:name => :other, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param2)

      @scope.lookupdefaults(:mytype).should == {:myparam => param1, :other => param2}
    end

    it "should look up defaults defined in parent scopes" do
      param1 = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param1)

      child_scope = @scope.newscope
      param2 = Puppet::Parser::Resource::Param.new(:name => :other, :value => "myvalue", :source => stub("source"))
      child_scope.define_settings(:mytype, param2)

      child_scope.lookupdefaults(:mytype).should == {:myparam => param1, :other => param2}
    end
  end

  context "#true?" do
    { "a string" => true,
      "true"     => true,
      "false"    => true,
      true       => true,
      ""         => false,
      :undef     => false,
      nil        => false
    }.each do |input, output|
      it "should treat #{input.inspect} as #{output}" do
        Puppet::Parser::Scope.true?(input).should == output
      end
    end
  end

  context "when producing a hash of all variables (as used in templates)" do
    it "should contain all defined variables in the scope" do
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.to_hash.should == {'orange' => :tangerine, 'pear' => :green }
    end

    it "should contain variables in all local scopes (#21508)" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      @scope.to_hash.should == {'orange' => :tangerine, 'pear' => :green, 'apple' => :red }
    end

    it "should contain all defined variables in the scope and all local scopes" do
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      @scope.to_hash.should == {'orange' => :tangerine, 'pear' => :green, 'apple' => :red }
    end

    it "should not contain varaibles in match scopes (non local emphemeral)" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.ephemeral_from(/(f)(o)(o)/.match('foo'))
      @scope.to_hash.should == {'orange' => :tangerine, 'pear' => :green }
    end

    it "should delete values that are :undef in inner scope" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      @scope.setvar("orange", :undef)
      @scope.to_hash.should == {'pear' => :green, 'apple' => :red }
    end
  end
end
