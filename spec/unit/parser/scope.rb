#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Scope do
    before :each do
        @topscope = Puppet::Parser::Scope.new()
        # This is necessary so we don't try to use the compiler to discover our parent.
        @topscope.parent = nil
        @scope = Puppet::Parser::Scope.new()
        @scope.parent = @topscope
    end

    describe "when looking up a variable" do
        it "should default to an empty string" do
            @scope.lookupvar("var").should == ""
        end

        it "should return an string when asked for a string" do
            @scope.lookupvar("var", true).should == ""
        end

        it "should return ':undefined' for unset variables when asked not to return a string" do
            @scope.lookupvar("var", false).should == :undefined
        end

        it "should be able to look up values" do
            @scope.setvar("var", "yep")
            @scope.lookupvar("var").should == "yep"
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
                @parser = Puppet::Parser::Parser.new()
                @compiler = Puppet::Parser::Compiler.new(stub("node", :name => "foonode", :classes => []), @parser)
                @scope.compiler = @compiler
                @scope.parser = @parser
            end

            def create_class_scope(name)
                klass = @parser.newclass(name)
                Puppet::Parser::Resource.new(:type => "class", :title => name, :scope => @scope, :source => mock('source')).evaluate

                return @compiler.class_scope(klass)
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

            it "should return an empty string for qualified variables that cannot be found in other classes" do
                other_scope = create_class_scope("other::deep::klass")

                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should warn and return an empty string for qualified variables whose classes have not been evaluated" do
                klass = @parser.newclass("other::deep::klass")
                @scope.expects(:warning)
                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should warn and return an empty string for qualified variables whose classes do not exist" do
                @scope.expects(:warning)
                @scope.lookupvar("other::deep::klass::var").should == ""
            end

            it "should return ':undefined' when asked for a non-string qualified variable from a class that does not exist" do
                @scope.stubs(:warning)
                @scope.lookupvar("other::deep::klass::var", false).should == :undefined
            end

            it "should return ':undefined' when asked for a non-string qualified variable from a class that has not been evaluated" do
                @scope.stubs(:warning)
                klass = @parser.newclass("other::deep::klass")
                @scope.lookupvar("other::deep::klass::var", false).should == :undefined
            end
        end
    end

    describe "when setvar is called with append=true" do
        it "should raise error if the variable is already defined in this scope" do
            @scope.setvar("var","1", :append => false)
            lambda { @scope.setvar("var","1", :append => true) }.should raise_error(Puppet::ParseError)
        end

        it "it should lookup current variable value" do
            @scope.expects(:lookupvar).with("var").returns("2")
            @scope.setvar("var","1", :append => true)
        end

        it "it should store the concatenated string '42'" do
            @topscope.setvar("var","4", :append => false)
            @scope.setvar("var","2", :append => true)
            @scope.lookupvar("var").should == "42"
        end

        it "it should store the concatenated array [4,2]" do
            @topscope.setvar("var",[4], :append => false)
            @scope.setvar("var",[2], :append => true)
            @scope.lookupvar("var").should == [4,2]
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

            @scope.lookupvar("1", false).should == :undefined
        end

        it "should not remove classic variables when unset_ephemeral_var is called" do
            @scope.setvar("myvar", :value1)
            @scope.setvar("1", :value2, :ephemeral => true)
            @scope.stubs(:parent).returns(nil)

            @scope.unset_ephemeral_var

            @scope.lookupvar("myvar", false).should == :value1
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
                @scope.lookupvar("0", false).should == :latest
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
                @scope.lookupvar("1", false).should == :value1
            end

            describe "when calling unset_ephemeral_var without a level" do
                it "should remove all the variables values"  do
                    @scope.setvar("1", :value1, :ephemeral => true)
                    @scope.new_ephemeral
                    @scope.setvar("1", :value2, :ephemeral => true)

                    @scope.unset_ephemeral_var

                    @scope.lookupvar("1", false).should == :undefined
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

                    @scope.lookupvar("1", false).should == :value2
                end
            end
        end
    end

    describe "when interpolating string" do
        (0..9).each do |n|
            it "should allow $#{n} to match" do
                @scope.setvar(n.to_s, "value", :ephemeral => true)

                @scope.strinterp("$#{n}").should == "value"
            end
        end

        (0..9).each do |n|
            it "should not allow $#{n} to match if not ephemeral" do
                @scope.setvar(n.to_s, "value", :ephemeral => false)

                @scope.strinterp("$#{n}").should_not == "value"
            end
        end

        it "should not allow $10 to match" do
            @scope.setvar("10", "value", :ephemeral => true)

            @scope.strinterp('==$10==').should_not == "==value=="
        end

        it "should not allow ${10} to match" do
            @scope.setvar("10", "value", :ephemeral => true)

            @scope.strinterp('==${10}==').should == "==value=="
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
            @scope.lookupvar("foo").should == ""
        end

        it "should be able to unset ephemeral variables" do
            @scope.setvar("0", "bar", :ephemeral => true)
            @scope.unsetvar("0")
            @scope.lookupvar("0").should == ""
        end

        it "should not unset ephemeral variables in previous ephemeral scope" do
            @scope.setvar("0", "bar", :ephemeral => true)
            @scope.new_ephemeral
            @scope.unsetvar("0")
            @scope.lookupvar("0").should == "bar"
        end
    end
end
