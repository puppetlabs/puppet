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
            @leaf.stubs(:safeevaluate).with(@scope).returns(@value)
            @value.expects(:==).with("value")

            @leaf.evaluate_match("value", @scope)
        end

        it "should downcase the evaluated value if wanted" do
            @leaf.stubs(:safeevaluate).with(@scope).returns(@value)
            @value.expects(:downcase).returns("value")

            @leaf.evaluate_match("value", @scope, :insensitive => true)
        end

        it "should downcase the parameter value if wanted" do
            parameter = stub 'parameter'
            parameter.expects(:downcase).returns("value")

            @leaf.evaluate_match(parameter, @scope, :insensitive => true)
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

describe Puppet::Parser::AST::Variable do
    describe "when converting to string" do
        it "should transform its value to a variable" do
            value = stub 'value', :is_a? => true, :to_s => "myvar"
            Puppet::Parser::AST::Variable.new( :value => value ).to_s.should == "\$myvar"
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

        it "should not downcase the paramater value" do
            @value.expects(:match).with("VaLuE")

            @regex.evaluate_match("VaLuE", @scope)
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

    it "should implement to_classname" do
        @host.should respond_to(:to_classname)
    end

    it "should return the downcased nodename as classname" do
        host = Puppet::Parser::AST::HostName.new( :value => "KLASSNAME" )
        host.to_classname.should == "klassname"
    end

    it "should preserve '_' in to_classname with a string nodename" do
        host = Puppet::Parser::AST::HostName.new( :value => "node_with_underscore")
        host.to_classname.should == "node_with_underscore"
    end

    it "should preserve '_' in to_classname with a regex nodename" do
        host = Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/\dnode_with_underscore\.+/") )
        host.to_classname.should == "dnode_with_underscore."
    end

    it "should return a string usable as classname when calling to_classname" do
        host = Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/^this-is not@a classname$/") )
        host.to_classname.should == "this-isnotaclassname"
    end

    it "should return a string usable as a tag when calling to_classname" do
        host = Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/.+.puppetlabs\.com/") )
        host.to_classname.should == "puppetlabs.com"
    end

    it "should delegate 'match' to the underlying value if it is an HostName" do
        @value.expects(:match).with("value")
        @host.match("value")
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

    it "should return true when regex? is called and value is a Regex" do
        @value.expects(:is_a?).with(Puppet::Parser::AST::Regex).returns(true)
        @host.regex?.should be_true
    end

    it "should return the results of comparing the regexes if asked whether a regex matches another regex" do
        hosts = [1,2].collect do |num|
            vreg = /vreg#{num}/
            value = Puppet::Parser::AST::Regex.new(:value => vreg)
            Puppet::Parser::AST::HostName.new(:value => value)
        end

        hosts[0].match(hosts[1]).should be_false
        hosts[0].match(hosts[0]).should be_true
    end

    it "should return false when comparing a non-regex to a regex" do
        vreg = /vreg/
        value = Puppet::Parser::AST::Regex.new(:value => vreg)
        regex = Puppet::Parser::AST::HostName.new(:value => value)

        value = Puppet::Parser::AST::Regex.new(:value => "foo")
        normal = Puppet::Parser::AST::HostName.new(:value => value)

        normal.match(regex).should be_false
    end

    it "should true when a provided string matches a regex" do
        vreg = /r/
        value = Puppet::Parser::AST::Regex.new(:value => vreg)
        regex = Puppet::Parser::AST::HostName.new(:value => value)

        value = Puppet::Parser::AST::Leaf.new(:value => "bar")
        normal = Puppet::Parser::AST::HostName.new(:value => value)

        regex.match(normal).should be_true
    end
end
