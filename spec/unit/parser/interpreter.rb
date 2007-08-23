#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

describe Puppet::Parser::Interpreter, " when creating parser instances" do
    before do
        @interp = Puppet::Parser::Interpreter.new
        @parser = mock('parser')
    end

    it "should create a parser with code passed in at initialization time" do
        @interp.code = :some_code
        @parser.expects(:code=).with(:some_code)
        @parser.expects(:parse)
        Puppet::Parser::Parser.expects(:new).with(:environment).returns(@parser)
        @interp.send(:create_parser, :environment).object_id.should equal(@parser.object_id)
    end

    it "should create a parser with a file passed in at initialization time" do
        @interp.file = :a_file
        @parser.expects(:file=).with(:a_file)
        @parser.expects(:parse)
        Puppet::Parser::Parser.expects(:new).with(:environment).returns(@parser)
        @interp.send(:create_parser, :environment).should equal(@parser)
    end

    it "should create a parser when passed neither code nor file" do
        @parser.expects(:parse)
        Puppet::Parser::Parser.expects(:new).with(:environment).returns(@parser)
        @interp.send(:create_parser, :environment).should equal(@parser)
    end

    it "should return nothing when new parsers fail" do
        Puppet::Parser::Parser.expects(:new).with(:environment).raises(ArgumentError)
        @interp.send(:create_parser, :environment).should be_nil
    end
end

describe Puppet::Parser::Interpreter, " when managing parser instances" do
    before do
        @interp = Puppet::Parser::Interpreter.new
        @parser = mock('parser')
    end

    it "it should an exception when nothing is there and nil is returned" do
        @interp.expects(:create_parser).with(:environment).returns(nil)
        lambda { @interp.send(:parser, :environment) }.should raise_error(Puppet::Error)
    end

    it "should create and return a new parser and use the same parser when the parser does not need reparsing" do
        @interp.expects(:create_parser).with(:environment).returns(@parser)
        @interp.send(:parser, :environment).should equal(@parser)

        @parser.expects(:reparse?).returns(false)
        @interp.send(:parser, :environment).should equal(@parser)
    end

    it "should create a new parser when reparse is true" do
        oldparser = mock('oldparser')
        newparser = mock('newparser')
        oldparser.expects(:reparse?).returns(true)
        oldparser.expects(:clear)

        @interp.expects(:create_parser).with(:environment).returns(oldparser)
        @interp.send(:parser, :environment).should equal(oldparser)
        @interp.expects(:create_parser).with(:environment).returns(newparser)
        @interp.send(:parser, :environment).should equal(newparser)
    end

    it "should keep the old parser if create_parser doesn't return anything." do
        # Get the first parser in the hash.
        @interp.expects(:create_parser).with(:environment).returns(@parser)
        @interp.send(:parser, :environment).should equal(@parser)

        # Have it indicate something has changed
        @parser.expects(:reparse?).returns(true)

        # But fail to create a new parser
        @interp.expects(:create_parser).with(:environment).returns(nil)

        # And make sure we still get the old valid parser
        @interp.send(:parser, :environment).should equal(@parser)
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
