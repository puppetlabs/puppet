#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Interpreter do
    before do
        @interp = Puppet::Parser::Interpreter.new
        @parser = mock 'parser'
    end

    describe "when creating parser instances" do
        it "should create a parser with code if there is code defined in the :code setting" do
            Puppet.settings.stubs(:uninterpolated_value).with(:code, :myenv).returns("mycode")
            @parser.expects(:string=).with("mycode")
            @parser.expects(:parse)
            Puppet::Parser::Parser.expects(:new).with(:myenv).returns(@parser)
            @interp.send(:create_parser, :myenv).object_id.should equal(@parser.object_id)
        end

        it "should create a parser with the main manifest when the code setting is an empty string" do
            Puppet.settings.stubs(:uninterpolated_value).with(:code, :myenv).returns("")
            Puppet.settings.stubs(:value).with(:manifest, :myenv).returns("/my/file")
            @parser.expects(:parse)
            @parser.expects(:file=).with("/my/file")
            Puppet::Parser::Parser.expects(:new).with(:myenv).returns(@parser)
            @interp.send(:create_parser, :myenv).should equal(@parser)
        end

        it "should return nothing when new parsers fail" do
            Puppet::Parser::Parser.expects(:new).with(:myenv).raises(ArgumentError)
            proc { @interp.send(:create_parser, :myenv) }.should raise_error(Puppet::Error)
        end

        it "should create parsers with environment-appropriate manifests" do
            # Set our per-environment values.  We can't just stub :value, because
            # it's called by too much of the rest of the code.
            text = "[env1]\nmanifest = /t/env1.pp\n[env2]\nmanifest = /t/env2.pp"
            FileTest.stubs(:exist?).returns true
            Puppet.settings.stubs(:read_file).returns(text)
            Puppet.settings.parse

            parser1 = mock 'parser1'
            Puppet::Parser::Parser.expects(:new).with(:env1).returns(parser1)
            parser1.expects(:file=).with("/t/env1.pp")
            parser1.expects(:parse)
            @interp.send(:create_parser, :env1)

            parser2 = mock 'parser2'
            Puppet::Parser::Parser.expects(:new).with(:env2).returns(parser2)
            parser2.expects(:file=).with("/t/env2.pp")
            parser2.expects(:parse)
            @interp.send(:create_parser, :env2)
        end
    end

    describe "when managing parser instances" do
        it "should use the same parser when the parser does not need reparsing" do
            @interp.expects(:create_parser).with(:myenv).returns(@parser)
            @interp.send(:parser, :myenv).should equal(@parser)

            @parser.expects(:reparse?).returns(false)
            @interp.send(:parser, :myenv).should equal(@parser)
        end

        it "should fail intelligently if a parser cannot be created and one does not already exist" do
            @interp.expects(:create_parser).with(:myenv).raises(ArgumentError)
            proc { @interp.send(:parser, :myenv) }.should raise_error(ArgumentError)
        end

        it "should use different parsers for different environments" do
            # get one for the first env
            @interp.expects(:create_parser).with(:first_env).returns(@parser)
            @interp.send(:parser, :first_env).should equal(@parser)

            other_parser = mock('otherparser')
            @interp.expects(:create_parser).with(:second_env).returns(other_parser)
            @interp.send(:parser, :second_env).should equal(other_parser)
        end

        describe "when files need reparsing" do
            it "should create a new parser" do
                oldparser = mock('oldparser')
                newparser = mock('newparser')
                oldparser.expects(:reparse?).returns(true)

                @interp.expects(:create_parser).with(:myenv).returns(oldparser)
                @interp.send(:parser, :myenv).should equal(oldparser)
                @interp.expects(:create_parser).with(:myenv).returns(newparser)
                @interp.send(:parser, :myenv).should equal(newparser)
            end

            it "should raise an exception if a new parser cannot be created" do
                # Get the first parser in the hash.
                @interp.expects(:create_parser).with(:myenv).returns(@parser)
                @interp.send(:parser, :myenv).should equal(@parser)

                @parser.expects(:reparse?).returns(true)

                @interp.expects(:create_parser).with(:myenv).raises(Puppet::Error, "Could not parse")

                lambda { @interp.parser(:myenv) }.should raise_error(Puppet::Error)
            end
        end
    end

    describe "when compiling a catalog" do
        before do
            @node = stub 'node', :environment => :myenv
            @compiler = mock 'compile'
        end

        it "should create a compile with the node and parser" do
            catalog = stub 'catalog', :to_resource => nil
            @compiler.expects(:compile).returns(catalog)
            @interp.expects(:parser).with(:myenv).returns(@parser)
            Puppet::Parser::Compiler.expects(:new).with(@node, @parser).returns(@compiler)
            @interp.compile(@node)
        end

        it "should fail intelligently when no parser can be found" do
            @node.stubs(:name).returns("whatever")
            @interp.expects(:parser).with(:myenv).returns(nil)
            proc { @interp.compile(@node) }.should raise_error(Puppet::ParseError)
        end

        it "should return the results of the compile, converted to a plain resource catalog" do
            catalog = mock 'catalog'
            @compiler.expects(:compile).returns(catalog)
            @interp.stubs(:parser).returns(@parser)
            Puppet::Parser::Compiler.stubs(:new).returns(@compiler)

            catalog.expects(:to_resource).returns "my_resource_catalog"
            @interp.compile(@node).should == "my_resource_catalog"
        end
    end
end
