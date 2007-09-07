#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Interpreter, " when initializing" do
    it "should default to neither code nor file" do
        interp = Puppet::Parser::Interpreter.new
        interp.code.should be_nil
        interp.file.should be_nil
    end

    it "should set the code to parse" do
        interp = Puppet::Parser::Interpreter.new :Code => :code
        interp.code.should equal(:code)
    end

    it "should set the file to parse" do
        interp = Puppet::Parser::Interpreter.new :Manifest => :file
        interp.file.should equal(:file)
    end

    it "should set code and ignore manifest when both are present" do
        interp = Puppet::Parser::Interpreter.new :Code => :code, :Manifest => :file
        interp.code.should equal(:code)
        interp.file.should be_nil
    end

    it "should default to usenodes" do
        interp = Puppet::Parser::Interpreter.new
        interp.usenodes?.should be_true
    end

    it "should allow disabling of usenodes" do
        interp = Puppet::Parser::Interpreter.new :UseNodes => false
        interp.usenodes?.should be_false
    end
end

describe Puppet::Parser::Interpreter, " when creating parser instances" do
    before do
        @interp = Puppet::Parser::Interpreter.new
        @parser = mock('parser')
    end

    it "should create a parser with code passed in at initialization time" do
        @interp.code = :some_code
        @parser.expects(:string=).with(:some_code)
        @parser.expects(:parse)
        Puppet::Parser::Parser.expects(:new).with(:environment => :myenv).returns(@parser)
        @interp.send(:create_parser, :myenv).object_id.should equal(@parser.object_id)
    end

    it "should create a parser with a file passed in at initialization time" do
        @interp.file = :a_file
        @parser.expects(:file=).with(:a_file)
        @parser.expects(:parse)
        Puppet::Parser::Parser.expects(:new).with(:environment => :myenv).returns(@parser)
        @interp.send(:create_parser, :myenv).should equal(@parser)
    end

    it "should create a parser with the main manifest when passed neither code nor file" do
        @parser.expects(:parse)
        @parser.expects(:file=).with(Puppet[:manifest])
        Puppet::Parser::Parser.expects(:new).with(:environment => :myenv).returns(@parser)
        @interp.send(:create_parser, :myenv).should equal(@parser)
    end

    it "should return nothing when new parsers fail" do
        Puppet::Parser::Parser.expects(:new).with(:environment => :myenv).raises(ArgumentError)
        proc { @interp.send(:create_parser, :myenv) }.should raise_error(Puppet::Error)
    end

    it "should create parsers with environment-appropriate manifests" do
        # Set our per-environment values.  We can't just stub :value, because
        # it's called by too much of the rest of the code.
        text = "[env1]\nmanifest = /t/env1.pp\n[env2]\nmanifest = /t/env2.pp"
        file = mock 'file'
        file.stubs(:changed?).returns(true)
        file.stubs(:file).returns("/whatever")
        Puppet.config.stubs(:read_file).with(file).returns(text)
        Puppet.config.parse(file)

        parser1 = mock 'parser1'
        Puppet::Parser::Parser.expects(:new).with(:environment => :env1).returns(parser1)
        parser1.expects(:file=).with("/t/env1.pp")
        parser1.expects(:parse)
        @interp.send(:create_parser, :env1)

        parser2 = mock 'parser2'
        Puppet::Parser::Parser.expects(:new).with(:environment => :env2).returns(parser2)
        parser2.expects(:file=).with("/t/env2.pp")
        parser2.expects(:parse)
        @interp.send(:create_parser, :env2)
    end
end

describe Puppet::Parser::Interpreter, " when managing parser instances" do
    before do
        @interp = Puppet::Parser::Interpreter.new
        @parser = mock('parser')
    end

    it "it should an exception when nothing is there and nil is returned" do
        @interp.expects(:create_parser).with(:myenv).returns(nil)
        @interp.send(:parser, :myenv).should be_nil
    end

    it "should create and return a new parser and use the same parser when the parser does not need reparsing" do
        @interp.expects(:create_parser).with(:myenv).returns(@parser)
        @interp.send(:parser, :myenv).should equal(@parser)

        @parser.expects(:reparse?).returns(false)
        @interp.send(:parser, :myenv).should equal(@parser)
    end

    it "should create a new parser when reparse is true" do
        oldparser = mock('oldparser')
        newparser = mock('newparser')
        oldparser.expects(:reparse?).returns(true)
        oldparser.expects(:clear)

        @interp.expects(:create_parser).with(:myenv).returns(oldparser)
        @interp.send(:parser, :myenv).should equal(oldparser)
        @interp.expects(:create_parser).with(:myenv).returns(newparser)
        @interp.send(:parser, :myenv).should equal(newparser)
    end

    it "should keep the old parser if create_parser doesn't return anything." do
        # Get the first parser in the hash.
        @interp.expects(:create_parser).with(:myenv).returns(@parser)
        @interp.send(:parser, :myenv).should equal(@parser)

        # Have it indicate something has changed
        @parser.expects(:reparse?).returns(true)

        # But fail to create a new parser
        @interp.expects(:create_parser).with(:myenv).returns(nil)

        # And make sure we still get the old valid parser
        @interp.send(:parser, :myenv).should equal(@parser)
    end

    it "should use different parsers for different environments" do
        # get one for the first env
        @interp.expects(:create_parser).with(:first_env).returns(@parser)
        @interp.send(:parser, :first_env).should equal(@parser)

        other_parser = mock('otherparser')
        @interp.expects(:create_parser).with(:second_env).returns(other_parser)
        @interp.send(:parser, :second_env).should equal(other_parser)
    end
end

describe Puppet::Parser::Interpreter, " when compiling configurations" do
    before do
        @interp = Puppet::Parser::Interpreter.new
    end

    it "should create a configuration with the node, parser, and whether to use ast nodes" do
        node = mock('node')
        node.expects(:environment).returns(:myenv)
        compile = mock 'compile'
        compile.expects(:compile).returns(:config)
        parser = mock 'parser'
        @interp.expects(:parser).with(:myenv).returns(parser)
        @interp.expects(:usenodes?).returns(true)
        Puppet::Parser::Compile.expects(:new).with(node, parser, :ast_nodes => true).returns(compile)
        @interp.compile(node)

        # Now try it when usenodes is true
        @interp = Puppet::Parser::Interpreter.new :UseNodes => false
        node.expects(:environment).returns(:myenv)
        compile.expects(:compile).returns(:config)
        @interp.expects(:parser).with(:myenv).returns(parser)
        @interp.expects(:usenodes?).returns(false)
        Puppet::Parser::Compile.expects(:new).with(node, parser, :ast_nodes => false).returns(compile)
        @interp.compile(node).should equal(:config)
    end
end

describe Puppet::Parser::Interpreter, " when returning configuration version" do
    before do
        @interp = Puppet::Parser::Interpreter.new
    end

    it "should ask the appropriate parser for the configuration version" do
        node = mock 'node'
        node.expects(:environment).returns(:myenv)
        parser = mock 'parser'
        parser.expects(:version).returns(:myvers)
        @interp.expects(:parser).with(:myenv).returns(parser)
        @interp.configuration_version(node).should equal(:myvers)
    end
end
