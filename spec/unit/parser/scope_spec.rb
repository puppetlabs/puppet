#!/usr/bin/env rspec
require 'spec_helper'

describe Puppet::Parser::Scope do
  before :each do
    @topscope = Puppet::Parser::Scope.new
    # This is necessary so we don't try to use the compiler to discover our parent.
    @topscope.parent = nil
    @scope = Puppet::Parser::Scope.new
    @scope.compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foo"))
    @scope.parent = @topscope
  end

  it "should be able to store references to class scopes" do
    lambda { @scope.class_set "myname", "myscope" }.should_not raise_error
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
    env = stub 'environment'
    compiler = stub 'compiler', :environment => env
    scope = Puppet::Parser::Scope.new :compiler => compiler
    scope.environment.should equal(env)
  end

  it "should use the resource type collection helper to find its known resource types" do
    Puppet::Parser::Scope.ancestors.should include(Puppet::Resource::TypeCollectionHelper)
  end

  describe "when missing methods are called" do
    before :each do
      @env      = Puppet::Node::Environment.new('testing')
      @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new('foo', :environment => @env))
      @scope    = Puppet::Parser::Scope.new(:compiler => @compiler)
    end

    it "should load and call the method if it looks like a function and it exists" do
      @scope.function_sprintf(["%b", 123]).should == "1111011"
    end

    it "should raise NoMethodError if the method doesn't look like a function" do
      expect { @scope.sprintf(["%b", 123]) }.should raise_error(NoMethodError)
    end

    it "should raise NoMethodError if the method looks like a function but doesn't exist" do
      expect { @scope.function_fake_bs(['cows']) }.should raise_error(NoMethodError)
    end
  end

  describe "when initializing" do
    it "should extend itself with its environment's Functions module as well as the default" do
      env = Puppet::Node::Environment.new("myenv")
      compiler = stub 'compiler', :environment => env
      mod      = Module.new
      root_mod = Module.new
      Puppet::Parser::Functions.expects(:environment_module).with(Puppet::Node::Environment.root).returns root_mod
      Puppet::Parser::Functions.expects(:environment_module).with(env).returns mod

      Puppet::Parser::Scope.new(:compiler => compiler).singleton_class.ancestors.should be_include(mod)
    end

    it "should extend itself with the default Functions module if it has no environment" do
      mod = Module.new
      Puppet::Parser::Functions.expects(:environment_module).with(Puppet::Node::Environment.root).returns(mod)

      Puppet::Parser::Functions.expects(:environment_module).with(nil).returns mod

      Puppet::Parser::Scope.new.singleton_class.ancestors.should be_include(mod)
    end

    it "should remember if it is dynamic" do
      (!!Puppet::Parser::Scope.new(:dynamic => true).dynamic).should == true
    end

    it "should assume it is not dynamic" do
      (!Puppet::Parser::Scope.new.dynamic).should == true
    end
  end

  describe "when looking up a variable" do
    it "should return ':undefined' for unset variables" do
      @scope.lookupvar("var").should == :undefined
    end

    it "should be able to look up values" do
      @scope.setvar("var", "yep")
      @scope.lookupvar("var").should == "yep"
    end

    it "should be able to look up hashes" do
      @scope.setvar("var", {"a" => "b"})
      @scope.lookupvar("var").should == {"a" => "b"}
    end

    it "should be able to look up variables in parent scopes" do
      @topscope.setvar("var", "parentval")
      @scope.lookupvar("var").should == "parentval"
    end

    it "should prefer its own values to parent values" do
      @topscope.setvar("var", "parentval")
      @scope.setvar("var", "childval")
      @scope.lookupvar("var").should == "childval"
    end

    describe "and the variable is qualified" do
      before do
        @compiler = Puppet::Parser::Compiler.new(Puppet::Node.new("foonode"))
        @scope.compiler = @compiler
        @known_resource_types = @scope.known_resource_types
      end

      def newclass(name)
        @known_resource_types.add Puppet::Resource::Type.new(:hostclass, name)
      end

      def create_class_scope(name)
        klass = newclass(name)

        catalog = Puppet::Resource::Catalog.new
        catalog.add_resource(Puppet::Parser::Resource.new("stage", :main, :scope => Puppet::Parser::Scope.new))

        Puppet::Parser::Resource.new("class", name, :scope => @scope, :source => mock('source'), :catalog => catalog).evaluate

        @scope.class_scope(klass)
      end

      it "should be able to look up explicitly fully qualified variables from main" do
        other_scope = create_class_scope("")

        other_scope.setvar("othervar", "otherval")

        @scope.lookupvar("::othervar").should == "otherval"
      end

      it "should be able to look up explicitly fully qualified variables from other scopes" do
        other_scope = create_class_scope("other")

        other_scope.setvar("var", "otherval")

        @scope.lookupvar("::other::var").should == "otherval"
      end

      it "should be able to look up deeply qualified variables" do
        other_scope = create_class_scope("other::deep::klass")

        other_scope.setvar("var", "otherval")

        @scope.lookupvar("other::deep::klass::var").should == "otherval"
      end

      it "should return ':undefined' for qualified variables that cannot be found in other classes" do
        other_scope = create_class_scope("other::deep::klass")

        @scope.lookupvar("other::deep::klass::var").should == :undefined
      end

      it "should warn and return ':undefined' for qualified variables whose classes have not been evaluated" do
        klass = newclass("other::deep::klass")
        @scope.expects(:warning)
        @scope.lookupvar("other::deep::klass::var").should == :undefined
      end

      it "should warn and return ':undefined' for qualified variables whose classes do not exist" do
        @scope.expects(:warning)
        @scope.lookupvar("other::deep::klass::var").should == :undefined
      end

      it "should return ':undefined' when asked for a non-string qualified variable from a class that does not exist" do
        @scope.stubs(:warning)
        @scope.lookupvar("other::deep::klass::var").should == :undefined
      end

      it "should return ':undefined' when asked for a non-string qualified variable from a class that has not been evaluated" do
        @scope.stubs(:warning)
        klass = newclass("other::deep::klass")
        @scope.lookupvar("other::deep::klass::var").should == :undefined
      end
    end
  end

  describe "when setvar is called with append=true" do
    it "should raise error if the variable is already defined in this scope" do
      @scope.setvar("var","1", :append => false)
      lambda { @scope.setvar("var","1", :append => true) }.should raise_error(Puppet::ParseError)
    end

    it "should lookup current variable value" do
      @scope.expects(:lookupvar).with("var").returns("2")
      @scope.setvar("var","1", :append => true)
    end

    it "should store the concatenated string '42'" do
      @topscope.setvar("var","4", :append => false)
      @scope.setvar("var","2", :append => true)
      @scope.lookupvar("var").should == "42"
    end

    it "should store the concatenated array [4,2]" do
      @topscope.setvar("var",[4], :append => false)
      @scope.setvar("var",[2], :append => true)
      @scope.lookupvar("var").should == [4,2]
    end

    it "should store the merged hash {a => b, c => d}" do
      @topscope.setvar("var",{"a" => "b"}, :append => false)
      @scope.setvar("var",{"c" => "d"}, :append => true)
      @scope.lookupvar("var").should == {"a" => "b", "c" => "d"}
    end

    it "should raise an error when appending a hash with something other than another hash" do
      @topscope.setvar("var",{"a" => "b"}, :append => false)
      lambda { @scope.setvar("var","not a hash", :append => true) }.should raise_error
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
      @scope.setvar("1", :value, :ephemeral => true)

      @scope.lookupvar("1").should == :value
    end

    it "should remove the variable value when unset_ephemeral_var is called" do
      @scope.setvar("1", :value, :ephemeral => true)
      @scope.stubs(:parent).returns(nil)

      @scope.unset_ephemeral_var

      @scope.lookupvar("1").should == :undefined
    end

    it "should not remove classic variables when unset_ephemeral_var is called" do
      @scope.setvar("myvar", :value1)
      @scope.setvar("1", :value2, :ephemeral => true)
      @scope.stubs(:parent).returns(nil)

      @scope.unset_ephemeral_var

      @scope.lookupvar("myvar").should == :value1
    end

    it "should raise an error when setting it again" do
      @scope.setvar("1", :value2, :ephemeral => true)
      lambda { @scope.setvar("1", :value3, :ephemeral => true) }.should raise_error
    end

    it "should declare ephemeral number only variable names" do
      @scope.ephemeral?("0").should be_true
    end

    it "should not declare ephemeral other variable names" do
      @scope.ephemeral?("abc0").should be_nil
    end

    describe "with more than one level" do
      it "should prefer latest ephemeral scopes" do
        @scope.setvar("0", :earliest, :ephemeral => true)
        @scope.new_ephemeral
        @scope.setvar("0", :latest, :ephemeral => true)
        @scope.lookupvar("0").should == :latest
      end

      it "should be able to report the current level" do
        @scope.ephemeral_level.should == 1
        @scope.new_ephemeral
        @scope.ephemeral_level.should == 2
      end

      it "should check presence of an ephemeral variable accross multiple levels" do
        @scope.new_ephemeral
        @scope.setvar("1", :value1, :ephemeral => true)
        @scope.new_ephemeral
        @scope.setvar("0", :value2, :ephemeral => true)
        @scope.new_ephemeral
        @scope.ephemeral_include?("1").should be_true
      end

      it "should return false when an ephemeral variable doesn't exist in any ephemeral scope" do
        @scope.new_ephemeral
        @scope.setvar("1", :value1, :ephemeral => true)
        @scope.new_ephemeral
        @scope.setvar("0", :value2, :ephemeral => true)
        @scope.new_ephemeral
        @scope.ephemeral_include?("2").should be_false
      end

      it "should get ephemeral values from earlier scope when not in later" do
        @scope.setvar("1", :value1, :ephemeral => true)
        @scope.new_ephemeral
        @scope.setvar("0", :value2, :ephemeral => true)
        @scope.lookupvar("1").should == :value1
      end

      describe "when calling unset_ephemeral_var without a level" do
        it "should remove all the variables values"  do
          @scope.setvar("1", :value1, :ephemeral => true)
          @scope.new_ephemeral
          @scope.setvar("1", :value2, :ephemeral => true)

          @scope.unset_ephemeral_var

          @scope.lookupvar("1").should == :undefined
        end
      end

      describe "when calling unset_ephemeral_var with a level" do
        it "should remove ephemeral scopes up to this level" do
          @scope.setvar("1", :value1, :ephemeral => true)
          @scope.new_ephemeral
          @scope.setvar("1", :value2, :ephemeral => true)
          @scope.new_ephemeral
          @scope.setvar("1", :value3, :ephemeral => true)

          @scope.unset_ephemeral_var(2)

          @scope.lookupvar("1").should == :value2
        end
      end
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
      lambda { @scope.ephemeral_from("match") }.should raise_error
    end

    it "should set $0 with the full match" do
      @scope.expects(:setvar).with { |*arg| arg[0] == "0" and arg[1] == "this is a string" and arg[2][:ephemeral] }

      @scope.ephemeral_from(@match)
    end

    it "should set every capture as ephemeral var" do
      @match.stubs(:captures).returns([:capture1,:capture2])
      @scope.expects(:setvar).with { |*arg| arg[0] == "1" and arg[1] == :capture1 and arg[2][:ephemeral] }
      @scope.expects(:setvar).with { |*arg| arg[0] == "2" and arg[1] == :capture2 and arg[2][:ephemeral] }

      @scope.ephemeral_from(@match)
    end

    it "should create a new ephemeral level" do
      @scope.expects(:new_ephemeral)
      @scope.ephemeral_from(@match)
    end
  end

  describe "when unsetting variables" do
    it "should be able to unset normal variables" do
      @scope.setvar("foo", "bar")
      @scope.unsetvar("foo")
      @scope.lookupvar("foo").should == :undefined
    end

    it "should be able to unset ephemeral variables" do
      @scope.setvar("0", "bar", :ephemeral => true)
      @scope.unsetvar("0")
      @scope.lookupvar("0").should == :undefined
    end

    it "should not unset ephemeral variables in previous ephemeral scope" do
      @scope.setvar("0", "bar", :ephemeral => true)
      @scope.new_ephemeral
      @scope.unsetvar("0")
      @scope.lookupvar("0").should == "bar"
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
      @scope.setdefaults(:mytype, param)
      @scope.lookupdefaults(:mytype).should == {:myparam => param}
    end

    it "should fail if a default is already defined and a new default is being defined" do
      param = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.setdefaults(:mytype, param)
      lambda { @scope.setdefaults(:mytype, param) }.should raise_error(Puppet::ParseError)
    end

    it "should return multiple defaults at once" do
      param1 = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.setdefaults(:mytype, param1)
      param2 = Puppet::Parser::Resource::Param.new(:name => :other, :value => "myvalue", :source => stub("source"))
      @scope.setdefaults(:mytype, param2)

      @scope.lookupdefaults(:mytype).should == {:myparam => param1, :other => param2}
    end

    it "should look up defaults defined in parent scopes" do
      param1 = Puppet::Parser::Resource::Param.new(:name => :myparam, :value => "myvalue", :source => stub("source"))
      @scope.setdefaults(:mytype, param1)

      child_scope = @scope.newscope
      param2 = Puppet::Parser::Resource::Param.new(:name => :other, :value => "myvalue", :source => stub("source"))
      child_scope.setdefaults(:mytype, param2)

      child_scope.lookupdefaults(:mytype).should == {:myparam => param1, :other => param2}
    end
  end
end
