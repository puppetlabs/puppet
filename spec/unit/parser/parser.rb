#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser do

    ast = Puppet::Parser::AST

    before :each do
        @loaded_code = Puppet::Parser::LoadedCode.new
        @parser = Puppet::Parser::Parser.new :environment => "development", :loaded_code => @loaded_code
        @true_ast = Puppet::Parser::AST::Boolean.new :value => true
    end

    describe "when parsing append operator" do

        it "should not raise syntax errors" do
            lambda { @parser.parse("$var += something") }.should_not raise_error
        end

        it "shouldraise syntax error on incomplete syntax " do
            lambda { @parser.parse("$var += ") }.should raise_error
        end

        it "should call ast::VarDef with append=true" do
            ast::VarDef.expects(:new).with { |h| h[:append] == true }
            @parser.parse("$var += 2")
        end

        it "should work with arrays too" do
            ast::VarDef.expects(:new).with { |h| h[:append] == true }
            @parser.parse("$var += ['test']")
        end

    end

    describe "when parsing 'if'" do
        it "not, it should create the correct ast objects" do
            ast::Not.expects(:new).with { |h| h[:value].is_a?(ast::Boolean) }
            @parser.parse("if ! true { $var = 1 }")
        end

        it "boolean operation, it should create the correct ast objects" do
            ast::BooleanOperator.expects(:new).with {
                |h| h[:rval].is_a?(ast::Boolean) and h[:lval].is_a?(ast::Boolean) and h[:operator]=="or"
            }
            @parser.parse("if true or true { $var = 1 }")

        end

        it "comparison operation, it should create the correct ast objects" do
             ast::ComparisonOperator.expects(:new).with {
                 |h| h[:lval].is_a?(ast::Name) and h[:rval].is_a?(ast::Name) and h[:operator]=="<"
             }
             @parser.parse("if 1 < 2 { $var = 1 }")

        end

    end

    describe "when parsing if complex expressions" do
         it "should create a correct ast tree" do
             aststub = stub_everything 'ast'
             ast::ComparisonOperator.expects(:new).with {
                 |h| h[:rval].is_a?(ast::Name) and h[:lval].is_a?(ast::Name) and h[:operator]==">"
             }.returns(aststub)
             ast::ComparisonOperator.expects(:new).with {
                 |h| h[:rval].is_a?(ast::Name) and h[:lval].is_a?(ast::Name) and h[:operator]=="=="
             }.returns(aststub)
             ast::BooleanOperator.expects(:new).with {
                 |h| h[:rval]==aststub and h[:lval]==aststub and h[:operator]=="and"
             }
             @parser.parse("if (1 > 2) and (1 == 2) { $var = 1 }")
         end

         it "should raise an error on incorrect expression" do
             lambda { @parser.parse("if (1 > 2 > ) or (1 == 2) { $var = 1 }") }.should raise_error
        end

    end

    describe "when parsing resource references" do

        it "should not raise syntax errors" do
            lambda { @parser.parse('exec { test: param => File["a"] }') }.should_not raise_error
        end

        it "should not raise syntax errors with multiple references" do
            lambda { @parser.parse('exec { test: param => File["a","b"] }') }.should_not raise_error
        end

        it "should create an ast::ResourceReference" do
            ast::Resource.stubs(:new)
            ast::ResourceReference.expects(:new).with { |arg|
                arg[:line]==1 and arg[:type]=="File" and arg[:title].is_a?(ast::ASTArray)
            }
            @parser.parse('exec { test: command => File["a","b"] }')
        end
    end

    describe "when parsing resource overrides" do

        it "should not raise syntax errors" do
            lambda { @parser.parse('Resource["title"] { param => value }') }.should_not raise_error
        end

        it "should not raise syntax errors with multiple overrides" do
            lambda { @parser.parse('Resource["title1","title2"] { param => value }') }.should_not raise_error
        end

        it "should create an ast::ResourceOverride" do
            ast::ResourceOverride.expects(:new).with { |arg|
                arg[:line]==1 and arg[:object].is_a?(ast::ResourceReference) and arg[:params].is_a?(ast::ResourceParam)
            }
            @parser.parse('Resource["title1","title2"] { param => value }')
        end

    end

    describe "when parsing if statements" do

        it "should not raise errors with empty if" do
            lambda { @parser.parse("if true { }") }.should_not raise_error
        end

        it "should not raise errors with empty else" do
            lambda { @parser.parse("if false { notice('if') } else { }") }.should_not raise_error
        end

        it "should not raise errors with empty if and else" do
            lambda { @parser.parse("if false { } else { }") }.should_not raise_error
        end

        it "should create a nop node for empty branch" do
            ast::Nop.expects(:new)
            @parser.parse("if true { }")
        end

        it "should create a nop node for empty else branch" do
            ast::Nop.expects(:new)
            @parser.parse("if true { notice('test') } else { }")
        end

    end

    describe "when parsing function calls" do

        it "should not raise errors with no arguments" do
            lambda { @parser.parse("tag()") }.should_not raise_error
        end

        it "should not raise errors with rvalue function with no args" do
            lambda { @parser.parse("$a = template()") }.should_not raise_error
        end

        it "should not raise errors with arguments" do
            lambda { @parser.parse("notice(1)") }.should_not raise_error
        end

        it "should not raise errors with multiple arguments" do
            lambda { @parser.parse("notice(1,2)") }.should_not raise_error
        end

        it "should not raise errors with multiple arguments and a trailing comma" do
            lambda { @parser.parse("notice(1,2,)") }.should_not raise_error
        end

    end

    describe "when parsing arrays with trailing comma" do

        it "should not raise errors with a trailing comma" do
            lambda { @parser.parse("$a = [1,2,]") }.should_not raise_error
        end
    end

    describe "when instantiating class of same name" do

        before :each do
            @one = stub 'one', :is_a? => true
            @one.stubs(:is_a?).with(ast::ASTArray).returns(false)
            @one.stubs(:is_a?).with(ast).returns(true)

            @two = stub 'two'
            @two.stubs(:is_a?).with(ast::ASTArray).returns(false)
            @two.stubs(:is_a?).with(ast).returns(true)
        end

        it "should return the first class" do

            klass1 = @parser.newclass("one", { :code => @one })

            @parser.newclass("one", { :code => @two }).should == klass1
        end

        it "should concatenate code" do
            klass1 = @parser.newclass("one", { :code => @one })

            @parser.newclass("one", { :code => @two })

            klass1.code.children.should == [@one,@two]
        end
    end

    describe "when parsing comments before statement" do
        it "should associate the documentation to the statement AST node" do
            ast = @parser.parse("""
            # comment
            class test {}
            """)

            ast.hostclass("test").doc.should == "comment\n"
        end
    end

    describe "when building ast nodes" do
        it "should get lexer comments if ast node declares use_docs" do
            lexer = stub 'lexer'
            ast = mock 'ast', :nil? => false, :use_docs => true, :doc => ""
            @parser.stubs(:lexer).returns(lexer)

            Puppet::Parser::AST::Definition.expects(:new).returns(ast)
            lexer.expects(:getcomment).returns("comment")
            ast.expects(:doc=).with("comment")

            @parser.ast(Puppet::Parser::AST::Definition)
        end
    end

    describe "when creating a node" do
        before :each do
            @lexer = stub 'lexer'
            @lexer.stubs(:getcomment)
            @parser.stubs(:lexer).returns(@lexer)
            @node = stub_everything 'node'
            @parser.stubs(:ast).returns(@node)
            @parser.stubs(:node).returns(nil)

            @nodename = stub 'nodename', :is_a? => false, :to_classname => "node"
            @nodename.stubs(:is_a?).with(Puppet::Parser::AST::HostName).returns(true)
        end

        it "should get the lexer stacked comments" do
            @lexer.expects(:getcomment)

            @parser.newnode(@nodename)
        end

        it "should create an HostName if needed" do
            Puppet::Parser::AST::HostName.expects(:new).with(:value => "node").returns(@nodename)

            @parser.newnode("node")
        end

        it "should raise an error if the node already exists" do
            @loaded_code.stubs(:node).with(@nodename).returns(@node)

            lambda { @parser.newnode(@nodename) }.should raise_error
        end

        it "should store the created node in the loaded code" do
            @loaded_code.expects(:add_node).with(@nodename, @node)

            @parser.newnode(@nodename)
        end

        it "should create the node with code if provided" do
            @parser.stubs(:ast).with { |*args| args[1][:code] == :code }.returns(@node)

            @parser.newnode(@nodename, :code => :code)
        end

        it "should create the node with a parentclass if provided" do
            @parser.stubs(:ast).with { |*args| args[1][:parent] == :parent }.returns(@node)

            @parser.newnode(@nodename, :parent => :parent)
        end

        it "should set the node classname from the HostName" do
            @nodename.stubs(:to_classname).returns(:classname)

            @node.expects(:classname=).with(:classname)

            @parser.newnode(@nodename)
        end

        it "should return an array of nodes" do
            @parser.newnode(@nodename).should == [@node]
        end
    end

    describe "when retrieving a specific node" do
        it "should delegate to the loaded_code node" do
            @loaded_code.expects(:node).with("node")

            @parser.node("node")
        end
    end

    describe "when retrieving a specific class" do
        it "should delegate to the loaded code" do
            @loaded_code.expects(:hostclass).with("class")

            @parser.hostclass("class")
        end
    end

    describe "when retrieving a specific definitions" do
        it "should delegate to the loaded code" do
            @loaded_code.expects(:definition).with("define")

            @parser.definition("define")
        end
    end

    describe "when determining the configuration version" do
        it "should default to the current time" do
            time = Time.now

            Time.stubs(:now).returns time
            @parser.version.should == time.to_i
        end

        it "should use the output of the config_version setting if one is provided" do
            Puppet.settings.stubs(:[]).with(:config_version).returns("/my/foo")

            @parser.expects(:`).with("/my/foo").returns "output\n"
            @parser.version.should == "output"
        end
    end

    describe Puppet::Parser,"when looking up definitions" do
        it "should check for them by name" do
            @parser.stubs(:find_or_load).with("namespace","name",:definition).returns(:this_value)
            @parser.find_definition("namespace","name").should == :this_value
        end
    end

    describe Puppet::Parser,"when looking up hostclasses" do
        it "should check for them by name" do
            @parser.stubs(:find_or_load).with("namespace","name",:hostclass).returns(:this_value)
            @parser.find_hostclass("namespace","name").should == :this_value
        end
    end

    describe Puppet::Parser,"when looking up names" do
        before :each do
            @loaded_code = mock 'loaded code'
            @loaded_code.stubs(:find_my_type).with('loaded_namespace',  'loaded_name').returns(true)
            @loaded_code.stubs(:find_my_type).with('bogus_namespace',   'bogus_name' ).returns(false)
            @parser = Puppet::Parser::Parser.new :environment => "development",:loaded_code => @loaded_code
        end

        describe "that are already loaded" do
            it "should not try to load anything" do
                @parser.expects(:load).never
                @parser.find_or_load("loaded_namespace","loaded_name",:my_type)
            end
            it "should return true" do
                @parser.find_or_load("loaded_namespace","loaded_name",:my_type).should == true
            end
        end

        describe "that aren't already loaded" do
            it "should first attempt to load them with the all lowercase fully qualified name" do
                @loaded_code.stubs(:find_my_type).with("foo_namespace","foo_name").returns(false,true,true)
                @parser.expects(:load).with("foo_namespace::foo_name").returns(true).then.raises(Exception)
                @parser.find_or_load("Foo_namespace","Foo_name",:my_type).should == true
            end

            it "should next attempt to load them with the all lowercase namespace" do
                @loaded_code.stubs(:find_my_type).with("foo_namespace","foo_name").returns(false,false,true,true)
                @parser.expects(:load).with("foo_namespace::foo_name").returns(false).then.raises(Exception)
                @parser.expects(:load).with("foo_namespace"          ).returns(true ).then.raises(Exception)
                @parser.find_or_load("Foo_namespace","Foo_name",:my_type).should == true
            end

            it "should finally attempt to load them with the all lowercase unqualified name" do
                @loaded_code.stubs(:find_my_type).with("foo_namespace","foo_name").returns(false,false,false,true,true)
                @parser.expects(:load).with("foo_namespace::foo_name").returns(false).then.raises(Exception)
                @parser.expects(:load).with("foo_namespace"          ).returns(false).then.raises(Exception)
                @parser.expects(:load).with(               "foo_name").returns(true ).then.raises(Exception)
                @parser.find_or_load("Foo_namespace","Foo_name",:my_type).should == true
            end

            it "should return false if the name isn't found" do
                @parser.stubs(:load).returns(false)
                @parser.find_or_load("Bogus_namespace","Bogus_name",:my_type).should == false
            end
        end
    end

    describe Puppet::Parser,"when loading classnames" do
        before :each do
            @loaded_code = mock 'loaded code'
            @parser = Puppet::Parser::Parser.new :environment => "development",:loaded_code => @loaded_code
        end

        it "should just return false if the classname is empty" do
            @parser.expects(:import).never
            @parser.load("").should == false
        end

        it "should just return true if the item is loaded" do
            pending "Need to access internal state (@parser's @loaded) to force this"
            @parser.load("").should == false
        end
    end
end
