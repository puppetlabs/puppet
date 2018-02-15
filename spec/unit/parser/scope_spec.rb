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
      expect(scope).to be_a_kind_of(Puppet::Parser::Scope)
    end
    it "should set the source to a node resource" do
      expect(scope.source).to be_a_kind_of(Puppet::Resource::Type)
    end
    it "should have a compiler" do
      expect(scope.compiler).to be_a_kind_of(Puppet::Parser::Compiler)
    end
    it "should set the parent to the compiler topscope" do
      expect(scope.parent).to be(scope.compiler.topscope)
    end
  end

  it "should generate a simple string when inspecting a scope" do
    expect(@scope.inspect).to eq("Scope()")
  end

  it "should generate a simple string when inspecting a scope with a resource" do
    @scope.resource="foo::bar"
    expect(@scope.inspect).to eq("Scope(foo::bar)")
  end

  it "should generate a path if there is one on the puppet stack" do
    result = Puppet::Pops::PuppetStack.stack('/tmp/kansas.pp', 42, @scope, 'inspect', [])
    expect(result).to eq("Scope(/tmp/kansas.pp, 42)")
  end

  it "should generate an <env> shortened path if path points into the environment" do
    env_path = @scope.environment.configuration.path_to_env
    mocked_path = File.join(env_path, 'oz.pp')
    result = Puppet::Pops::PuppetStack.stack(mocked_path, 42, @scope, 'inspect', [])

    expect(result).to eq("Scope(<env>/oz.pp, 42)")
  end

  it "should generate a <module> shortened path if path points into a module" do
    mocked_path = File.join(@scope.environment.full_modulepath[0], 'mymodule', 'oz.pp')
    result = Puppet::Pops::PuppetStack.stack(mocked_path, 42, @scope, 'inspect', [])
    expect(result).to eq("Scope(<module>/mymodule/oz.pp, 42)")
  end

  it "should return a scope for use in a test harness" do
    expect(create_test_scope_for_node("node_name_foo")).to be_a_kind_of(Puppet::Parser::Scope)
  end

  it "should be able to retrieve class scopes by name" do
    @scope.class_set "myname", "myscope"
    expect(@scope.class_scope("myname")).to eq("myscope")
  end

  it "should be able to retrieve class scopes by object" do
    klass = mock 'ast_class'
    klass.expects(:name).returns("myname")
    @scope.class_set "myname", "myscope"
    expect(@scope.class_scope(klass)).to eq("myscope")
  end

  it "should be able to retrieve its parent module name from the source of its parent type" do
    @topscope.source = Puppet::Resource::Type.new(:hostclass, :foo, :module_name => "foo")

    expect(@scope.parent_module_name).to eq("foo")
  end

  it "should return a nil parent module name if it has no parent" do
    expect(@topscope.parent_module_name).to be_nil
  end

  it "should return a nil parent module name if its parent has no source" do
    expect(@scope.parent_module_name).to be_nil
  end

  it "should get its environment from its compiler" do
    env = Puppet::Node::Environment.create(:testing, [])
    compiler = stub 'compiler', :environment => env, :is_a? => true
    scope = Puppet::Parser::Scope.new(compiler)
    expect(scope.environment).to equal(env)
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

  describe "when custom functions are called" do
    let(:env) { Puppet::Node::Environment.create(:testing, []) }
    let(:compiler) { Puppet::Parser::Compiler.new(Puppet::Node.new('foo', :environment => env)) }
    let(:scope) { Puppet::Parser::Scope.new(compiler) }

    it "calls methods prefixed with function_ as custom functions" do
      expect(scope.function_sprintf(["%b", 123])).to eq("1111011")
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
      expect(scope.singleton_class.ancestors).to be_include(Puppet::Parser::Functions.environment_module(env))
      expect(scope.singleton_class.ancestors).to be_include(Puppet::Parser::Functions.environment_module(root))
    end

    it "should extend itself with the default Functions module if its environment is the default" do
      root     = Puppet.lookup(:root_environment)
      node     = Puppet::Node.new('localhost')
      compiler = Puppet::Parser::Compiler.new(node)
      scope    = Puppet::Parser::Scope.new(compiler)
      expect(scope.singleton_class.ancestors).to be_include(Puppet::Parser::Functions.environment_module(root))
    end
  end

  describe "when looking up a variable" do
    it "should support :lookupvar and :setvar for backward compatibility" do
      @scope.setvar("var", "yep")
      expect(@scope.lookupvar("var")).to eq("yep")
    end

    it "should fail if invoked with a non-string name" do
      expect { @scope[:foo] }.to raise_error(Puppet::ParseError, /Scope variable name .* not a string/)
      expect { @scope[:foo] = 12 }.to raise_error(Puppet::ParseError, /Scope variable name .* not a string/)
    end

    it "should return nil for unset variables when --strict variables is not in effect" do
      expect(@scope["var"]).to be_nil
    end

    it "answers exist? with boolean false for non existing variables" do
      expect(@scope.exist?("var")).to be(false)
    end

    it "answers exist? with boolean false for non existing variables" do
      @scope["var"] = "yep"
      expect(@scope.exist?("var")).to be(true)
    end

    it "should be able to look up values" do
      @scope["var"] = "yep"
      expect(@scope["var"]).to eq("yep")
    end

    it "should be able to look up hashes" do
      @scope["var"] = {"a" => "b"}
      expect(@scope["var"]).to eq({"a" => "b"})
    end

    it "should be able to look up variables in parent scopes" do
      @topscope["var"] = "parentval"
      expect(@scope["var"]).to eq("parentval")
    end

    it "should prefer its own values to parent values" do
      @topscope["var"] = "parentval"
      @scope["var"] = "childval"
      expect(@scope["var"]).to eq("childval")
    end

    it "should be able to detect when variables are set" do
      @scope["var"] = "childval"
      expect(@scope).to be_include("var")
    end

    it "does not allow changing a set value" do
      @scope["var"] = "childval"
      expect {
        @scope["var"] = "change"
      }.to raise_error(Puppet::Error, "Cannot reassign variable '$var'")
    end

    it "should be able to detect when variables are not set" do
      expect(@scope).not_to be_include("var")
    end

    it "warns and return nil for non found unqualified variable" do
      Puppet.expects(:warn_once)
      expect(@scope["santa_clause"]).to be_nil
    end

    it "warns once for a non found variable" do
      Puppet.expects(:send_log).with(:warning, is_a(String)).once
      expect([@scope["santa_claus"],@scope["santa_claus"]]).to eq([nil, nil])
    end

    it "warns and return nil for non found qualified variable" do
      Puppet.expects(:warn_once)
      expect(@scope["north_pole::santa_clause"]).to be_nil
    end

    it "does not warn when a numeric variable is missing - they always exist" do
      Puppet.expects(:warn_once).never
      expect(@scope["1"]).to be_nil
    end

    describe "and the variable is qualified" do
      before :each do
        @known_resource_types = @scope.environment.known_resource_types

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

      it "should be able to look up explicitly fully qualified variables from compiler's top scope" do
        Puppet.expects(:deprecation_warning).never
        other_scope = @scope.compiler.topscope

        other_scope["othervar"] = "otherval"

        expect(@scope["::othervar"]).to eq("otherval")
      end

      it "should be able to look up explicitly fully qualified variables from other scopes" do
        Puppet.expects(:deprecation_warning).never
        other_scope = create_class_scope("other")

        other_scope["var"] = "otherval"

        expect(@scope["::other::var"]).to eq("otherval")
      end

      it "should be able to look up deeply qualified variables" do
        Puppet.expects(:deprecation_warning).never
        other_scope = create_class_scope("other::deep::klass")

        other_scope["var"] = "otherval"

        expect(@scope["other::deep::klass::var"]).to eq("otherval")
      end

      it "should return nil for qualified variables that cannot be found in other classes" do
        create_class_scope("other::deep::klass")

        expect(@scope["other::deep::klass::var"]).to be_nil
      end

      it "should warn and return nil for qualified variables whose classes have not been evaluated" do
        newclass("other::deep::klass")
        Puppet.expects(:warn_once)
        expect(@scope["other::deep::klass::var"]).to be_nil
      end

      it "should warn and return nil for qualified variables whose classes do not exist" do
        Puppet.expects(:warn_once)
        expect(@scope["other::deep::klass::var"]).to be_nil
      end

      it "should return nil when asked for a non-string qualified variable from a class that does not exist" do
        expect(@scope["other::deep::klass::var"]).to be_nil
      end

      it "should return nil when asked for a non-string qualified variable from a class that has not been evaluated" do
        @scope.stubs(:warning)
        newclass("other::deep::klass")
        expect(@scope["other::deep::klass::var"]).to be_nil
      end
    end

    context "and strict_variables is true" do
      before(:each) do
        Puppet[:strict_variables] = true
      end

      it "should throw a symbol when unknown variable is looked up" do
        expect { @scope['john_doe'] }.to throw_symbol(:undefined_variable)
      end

      it "should throw a symbol when unknown qualified variable is looked up" do
        expect { @scope['nowhere::john_doe'] }.to throw_symbol(:undefined_variable)
      end

      it "should not raise an error when built in variable is looked up" do
        expect { @scope['caller_module_name'] }.to_not raise_error
        expect { @scope['module_name'] }.to_not raise_error
      end
    end

    context "and strict_variables is false and --strict=off" do
      before(:each) do
        Puppet[:strict_variables] = false
        Puppet[:strict] = :off
      end

      it "should not error when unknown variable is looked up and produce nil" do
        expect(@scope['john_doe']).to be_nil
      end

      it "should not error when unknown qualified variable is looked up and produce nil" do
        expect(@scope['nowhere::john_doe']).to be_nil
      end
    end

    context "and strict_variables is false and --strict=warning" do
      before(:each) do
        Puppet[:strict_variables] = false
        Puppet[:strict] = :warning
      end

      it "should not error when unknown variable is looked up" do
        expect(@scope['john_doe']).to be_nil
      end

      it "should not error when unknown qualified variable is looked up" do
        expect(@scope['nowhere::john_doe']).to be_nil
      end
    end

    context "and strict_variables is false and --strict=error" do
      before(:each) do
        Puppet[:strict_variables] = false
        Puppet[:strict] = :error
      end

      it "should raise error when unknown variable is looked up" do
        expect { @scope['john_doe'] }.to raise_error(/Undefined variable/)
      end

      it "should not throw a symbol when unknown qualified variable is looked up" do
        expect { @scope['nowhere::john_doe'] }.to raise_error(/Undefined variable/)
      end
    end
  end

  describe "when calling number?" do
    it "should return nil if called with anything not a number" do
      expect(Puppet::Parser::Scope.number?([2])).to be_nil
    end

    it "should return a Integer for an Integer" do
      expect(Puppet::Parser::Scope.number?(2)).to be_a(Integer)
    end

    it "should return a Float for a Float" do
      expect(Puppet::Parser::Scope.number?(2.34)).to be_an_instance_of(Float)
    end

    it "should return 234 for '234'" do
      expect(Puppet::Parser::Scope.number?("234")).to eq(234)
    end

    it "should return nil for 'not a number'" do
      expect(Puppet::Parser::Scope.number?("not a number")).to be_nil
    end

    it "should return 23.4 for '23.4'" do
      expect(Puppet::Parser::Scope.number?("23.4")).to eq(23.4)
    end

    it "should return 23.4e13 for '23.4e13'" do
      expect(Puppet::Parser::Scope.number?("23.4e13")).to eq(23.4e13)
    end

    it "should understand negative numbers" do
      expect(Puppet::Parser::Scope.number?("-234")).to eq(-234)
    end

    it "should know how to convert exponential float numbers ala '23e13'" do
      expect(Puppet::Parser::Scope.number?("23e13")).to eq(23e13)
    end

    it "should understand hexadecimal numbers" do
      expect(Puppet::Parser::Scope.number?("0x234")).to eq(0x234)
    end

    it "should understand octal numbers" do
      expect(Puppet::Parser::Scope.number?("0755")).to eq(0755)
    end

    it "should return nil on malformed integers" do
      expect(Puppet::Parser::Scope.number?("0.24.5")).to be_nil
    end

    it "should convert strings with leading 0 to integer if they are not octal" do
      expect(Puppet::Parser::Scope.number?("0788")).to eq(788)
    end

    it "should convert strings of negative integers" do
      expect(Puppet::Parser::Scope.number?("-0788")).to eq(-788)
    end

    it "should return nil on malformed hexadecimal numbers" do
      expect(Puppet::Parser::Scope.number?("0x89g")).to be_nil
    end
  end

  describe "when using ephemeral variables" do
    it "should store the variable value" do
      @scope.set_match_data({1 => :value})
      expect(@scope["1"]).to eq(:value)
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
        expect(@scope["0"]).to eq(:latest)
      end

      it "should be able to report the current level" do
        expect(@scope.ephemeral_level).to eq(1)
        @scope.new_ephemeral
        expect(@scope.ephemeral_level).to eq(2)
      end

      it "should not check presence of an ephemeral variable across multiple levels" do
        @scope.new_ephemeral
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        @scope.new_ephemeral
        expect(@scope.include?("1")).to be_falsey
      end

      it "should return false when an ephemeral variable doesn't exist in any ephemeral scope" do
        @scope.new_ephemeral
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        @scope.new_ephemeral
        expect(@scope.include?("2")).to be_falsey
      end

      it "should not get ephemeral values from earlier scope when not in later" do
        @scope.set_match_data({1 => :value1})
        @scope.new_ephemeral
        @scope.set_match_data({0 => :value2})
        expect(@scope.include?("1")).to be_falsey
      end

      describe "when using a guarded scope" do
        it "should remove ephemeral scopes up to this level" do
          @scope.set_match_data({1 => :value1})
          @scope.new_ephemeral
          @scope.set_match_data({1 => :value2})
          @scope.with_guarded_scope do
            @scope.new_ephemeral
            @scope.set_match_data({1 => :value3})
          end
          expect(@scope["1"]).to eq(:value2)
        end
      end
    end
  end

  context "when using ephemeral as local scope" do
    it "should store all variables in local scope" do
      @scope.new_ephemeral true
      @scope.setvar("apple", :fruit)
      expect(@scope["apple"]).to eq(:fruit)
    end

    it 'should store an undef in local scope and let it override parent scope' do
      @scope['cloaked'] = 'Cloak me please'
      @scope.new_ephemeral(true)
      @scope['cloaked'] = nil
      expect(@scope['cloaked']).to eq(nil)
    end

    it "should be created from a hash" do
      @scope.ephemeral_from({ "apple" => :fruit, "strawberry" => :berry})
      expect(@scope["apple"]).to eq(:fruit)
      expect(@scope["strawberry"]).to eq(:berry)
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
      expect(@scope.lookupvar('2')).to eq(nil)
    end

    it "should create a new ephemeral level" do
      level_before = @scope.ephemeral_level
      @scope.ephemeral_from(@match)
      expect(level_before < @scope.ephemeral_level)
    end
  end

  describe "when managing defaults" do
    it "should be able to set and lookup defaults" do
      param = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param)
      expect(@scope.lookupdefaults(:mytype)).to eq({:myparam => param})
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

      expect(@scope.lookupdefaults(:mytype)).to eq({:myparam => param1, :other => param2})
    end

    it "should look up defaults defined in parent scopes" do
      param1 = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.define_settings(:mytype, param1)

      child_scope = @scope.newscope
      param2 = Puppet::Parser::Resource::Param.new(:name => :other, :value => "myvalue", :source => stub("source"))
      child_scope.define_settings(:mytype, param2)

      expect(child_scope.lookupdefaults(:mytype)).to eq({:myparam => param1, :other => param2})
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
        expect(Puppet::Parser::Scope.true?(input)).to eq(output)
      end
    end
  end

  context "when producing a hash of all variables (as used in templates)" do
    it "should contain all defined variables in the scope" do
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      expect(@scope.to_hash).to eq({'orange' => :tangerine, 'pear' => :green })
    end

    it "should contain variables in all local scopes (#21508)" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      expect(@scope.to_hash).to eq({'orange' => :tangerine, 'pear' => :green, 'apple' => :red })
    end

    it "should contain all defined variables in the scope and all local scopes" do
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      expect(@scope.to_hash).to eq({'orange' => :tangerine, 'pear' => :green, 'apple' => :red })
    end

    it "should not contain varaibles in match scopes (non local emphemeral)" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.ephemeral_from(/(f)(o)(o)/.match('foo'))
      expect(@scope.to_hash).to eq({'orange' => :tangerine, 'pear' => :green })
    end

    it "should delete values that are :undef in inner scope" do
      @scope.new_ephemeral true
      @scope.setvar("orange", :tangerine)
      @scope.setvar("pear", :green)
      @scope.new_ephemeral true
      @scope.setvar("apple", :red)
      @scope.setvar("orange", :undef)
      expect(@scope.to_hash).to eq({'pear' => :green, 'apple' => :red })
    end
  end
end
