#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Leaf do
    before :each do
        @scope = stub 'scope'
        @value = stub 'value'
        @leaf = Puppet::Parser::AST::Leaf.new(:value => @value)
    end

    it "should have a evaluate_match method" do
        Puppet::Parser::AST::Leaf.new(:value => "value").should respond_to(:evaluate_match)
    end

    describe "when evaluate_match is called" do
        it "should evaluate itself" do
            @leaf.expects(:safeevaluate).with(@scope)

            @leaf.evaluate_match("value", @scope)
        end

        it "should match values by equality" do
            @value.stubs(:==).returns(false)
            @leaf.stubs(:safeevaluate).with(@scope).returns(@value)
            @value.expects(:==).with("value")

            @leaf.evaluate_match("value", @scope)
        end

        it "should downcase the evaluated value if wanted" do
            @leaf.stubs(:safeevaluate).with(@scope).returns(@value)
            @value.expects(:downcase).returns("value")

            @leaf.evaluate_match("value", @scope, :insensitive => true)
        end

        it "should match undef if value is an empty string" do
            @leaf.stubs(:safeevaluate).with(@scope).returns("")

            @leaf.evaluate_match(:undef, @scope).should be_true
        end
    end

    describe "when converting to string" do
        it "should transform its value to string" do
            value = stub 'value', :is_a? => true
            value.expects(:to_s)
            Puppet::Parser::AST::Leaf.new( :value => value ).to_s
        end
    end

    it "should have a match method" do
        @leaf.should respond_to(:match)
    end

    it "should delegate match to ==" do
        @value.expects(:==).with("value")

        @leaf.match("value")
    end
end

describe Puppet::Parser::AST::FlatString do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::FlatString.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end

describe Puppet::Parser::AST::String do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::String.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end

describe Puppet::Parser::AST::Undef do
    before :each do
        @scope = stub 'scope'
        @undef = Puppet::Parser::AST::Undef.new(:value => :undef)
    end

    it "should match undef with undef" do
        @undef.evaluate_match(:undef, @scope).should be_true
    end

    it "should not match undef with an empty string" do
        @undef.evaluate_match("", @scope).should be_false
    end
end

describe Puppet::Parser::AST::HashOrArrayAccess do
    before :each do
        @scope = stub 'scope'
    end

    describe "when evaluating" do
        it "should evaluate the variable part if necessary" do
            @scope.stubs(:lookupvar).with("a").returns(["b"])

            variable = stub 'variable', :evaluate => "a"
            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => variable, :key => 0 )

            variable.expects(:safeevaluate).with(@scope).returns("a")

            access.evaluate(@scope).should == "b"
        end

        it "should evaluate the access key part if necessary" do
            @scope.stubs(:lookupvar).with("a").returns(["b"])

            index = stub 'index', :evaluate => 0
            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => index )

            index.expects(:safeevaluate).with(@scope).returns(0)

            access.evaluate(@scope).should == "b"
        end

        it "should be able to return an array member" do
            @scope.stubs(:lookupvar).with("a").returns(["val1", "val2", "val3"])

            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => 1 )

            access.evaluate(@scope).should == "val2"
        end

        it "should be able to return an hash value" do
            @scope.stubs(:lookupvar).with("a").returns({ "key1" => "val1", "key2" => "val2", "key3" => "val3" })

            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

            access.evaluate(@scope).should == "val2"
        end

        it "should raise an error if the variable lookup didn't return an hash or an array" do
            @scope.stubs(:lookupvar).with("a").returns("I'm a string")

            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

            lambda { access.evaluate(@scope) }.should raise_error
        end

        it "should raise an error if the variable wasn't in the scope" do
            @scope.stubs(:lookupvar).with("a").returns(nil)

            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )

            lambda { access.evaluate(@scope) }.should raise_error
        end

        it "should return a correct string representation" do
            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key2" )
            access.to_s.should == '$a[key2]'
        end

        it "should work with recursive hash access" do
            @scope.stubs(:lookupvar).with("a").returns({ "key" => { "subkey" => "b" }})

            access1 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")
            access2 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => access1, :key => "subkey")

            access2.evaluate(@scope).should == 'b'
        end

        it "should work with interleaved array and hash access" do
            @scope.stubs(:lookupvar).with("a").returns({ "key" => [ "a" , "b" ]})

            access1 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")
            access2 = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => access1, :key => 1)

            access2.evaluate(@scope).should == 'b'
        end
    end

    describe "when assigning" do
        it "should add a new key and value" do
            scope = Puppet::Parser::Scope.new
            scope.setvar("a", { 'a' => 'b' })

            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "b")
            access.assign(scope, "c" )

            scope.lookupvar("a").should be_include("b")
        end

        it "should raise an error when trying to overwrite an hash value" do
            @scope.stubs(:lookupvar).with("a").returns({ "key" => [ "a" , "b" ]})
            access = Puppet::Parser::AST::HashOrArrayAccess.new(:variable => "a", :key => "key")

            lambda { access.assign(@scope, "test") }.should raise_error
        end
    end
end

describe Puppet::Parser::AST::Regex do
    before :each do
        @scope = stub 'scope'
    end

    describe "when initializing" do
        it "should create a Regexp with its content when value is not a Regexp" do
            Regexp.expects(:new).with("/ab/")

            Puppet::Parser::AST::Regex.new :value => "/ab/"
        end

        it "should not create a Regexp with its content when value is a Regexp" do
            value = Regexp.new("/ab/")
            Regexp.expects(:new).with("/ab/").never

            Puppet::Parser::AST::Regex.new :value => value
        end
    end

    describe "when evaluating" do
        it "should return self" do
            val = Puppet::Parser::AST::Regex.new :value => "/ab/"

            val.evaluate(@scope).should === val
        end
    end

    describe "when evaluate_match" do
        before :each do
            @value = stub 'regex'
            @value.stubs(:match).with("value").returns(true)
            Regexp.stubs(:new).returns(@value)
            @regex = Puppet::Parser::AST::Regex.new :value => "/ab/"
        end

        it "should issue the regexp match" do
            @value.expects(:match).with("value")

            @regex.evaluate_match("value", @scope)
        end

        it "should set ephemeral scope vars if there is a match" do
            @scope.expects(:ephemeral_from).with(true, nil, nil)

            @regex.evaluate_match("value", @scope)
        end

        it "should return the match to the caller" do
            @value.stubs(:match).with("value").returns(:match)
            @scope.stubs(:ephemeral_from)

            @regex.evaluate_match("value", @scope)
        end
    end

    it "should return the regex source with to_s" do
        regex = stub 'regex'
        Regexp.stubs(:new).returns(regex)

        val = Puppet::Parser::AST::Regex.new :value => "/ab/"

        regex.expects(:source)

        val.to_s
    end

    it "should delegate match to the underlying regexp match method" do
        regex = Regexp.new("/ab/")
        val = Puppet::Parser::AST::Regex.new :value => regex

        regex.expects(:match).with("value")

        val.match("value")
    end
end

describe Puppet::Parser::AST::Variable do
    before :each do
        @scope = stub 'scope'
        @var = Puppet::Parser::AST::Variable.new(:value => "myvar")
    end

    it "should lookup the variable in scope" do
        @scope.expects(:lookupvar).with("myvar", false).returns(:myvalue)
        @var.safeevaluate(@scope).should == :myvalue
    end

    it "should return undef if the variable wasn't set" do
        @scope.expects(:lookupvar).with("myvar", false).returns(:undefined)
        @var.safeevaluate(@scope).should == :undef
    end

    describe "when converting to string" do
        it "should transform its value to a variable" do
            value = stub 'value', :is_a? => true, :to_s => "myvar"
            Puppet::Parser::AST::Variable.new( :value => value ).to_s.should == "\$myvar"
        end
    end
end

describe Puppet::Parser::AST::HostName do
    before :each do
        @scope = stub 'scope'
        @value = stub 'value', :=~ => false
        @value.stubs(:to_s).returns(@value)
        @value.stubs(:downcase).returns(@value)
        @host = Puppet::Parser::AST::HostName.new( :value => @value)
    end

    it "should raise an error if hostname is not valid" do
        lambda { Puppet::Parser::AST::HostName.new( :value => "not an hostname!" ) }.should raise_error
    end

    it "should not raise an error if hostname is a regex" do
        lambda { Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/test/") ) }.should_not raise_error
    end

    it "should stringify the value" do
        value = stub 'value', :=~ => false

        value.expects(:to_s).returns("test")

        Puppet::Parser::AST::HostName.new(:value => value)
    end

    it "should downcase the value" do
        value = stub 'value', :=~ => false
        value.stubs(:to_s).returns("UPCASED")
        host = Puppet::Parser::AST::HostName.new(:value => value)

        host.value == "upcased"
    end

    it "should evaluate to its value" do
        @host.evaluate(@scope).should == @value
    end

    it "should delegate eql? to the underlying value if it is an HostName" do
        @value.expects(:eql?).with("value")
        @host.eql?("value")
    end

    it "should delegate eql? to the underlying value if it is not an HostName" do
        value = stub 'compared', :is_a? => true, :value => "value"
        @value.expects(:eql?).with("value")
        @host.eql?(value)
    end

    it "should delegate hash to the underlying value" do
        @value.expects(:hash)
        @host.hash
    end
end
