#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/util/rdoc'
require 'rdoc/rdoc'

describe Puppet::Util::RDoc do
  describe "when generating RDoc HTML documentation" do
    before :each do
      @rdoc = stub_everything 'rdoc'
      RDoc::RDoc.stubs(:new).returns(@rdoc)
    end

    it "should tell the parser to ignore import" do
      Puppet.expects(:[]=).with(:ignoreimport, true)
      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should tell RDoc to generate documentation using the Puppet generator" do
      @rdoc.expects(:document).with { |args| args.include?("--fmt") and args.include?("puppet") }

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should tell RDoc to be quiet" do
      @rdoc.expects(:document).with { |args| args.include?("--quiet") }

      Puppet::Util::RDoc.rdoc("output", [])
    end

    it "should pass charset to RDoc" do
      @rdoc.expects(:document).with { |args| args.include?("--charset") and args.include?("utf-8") }

      Puppet::Util::RDoc.rdoc("output", [], "utf-8")
    end

    describe "with rdoc1", :if => Puppet.features.rdoc1? do
      it "should install the Puppet HTML Generator into RDoc generators" do
        Puppet::Util::RDoc.rdoc("output", [])

        RDoc::RDoc::GENERATORS["puppet"].file_name.should == "puppet/util/rdoc/generators/puppet_generator.rb"
      end

      it "should tell RDoc to force updates of indices when RDoc supports it" do
        ::Options::OptionList.stubs(:options).returns([["--force-update", "-U", 0 ]])
        @rdoc.expects(:document).with { |args| args.include?("--force-update") }

        Puppet::Util::RDoc.rdoc("output", [])
      end

      it "should not tell RDoc to force updates of indices when RDoc doesn't support it" do
        ::Options::OptionList.stubs(:options).returns([])
        @rdoc.expects(:document).never.with { |args| args.include?("--force-update") }

        Puppet::Util::RDoc.rdoc("output", [])
      end
    end

    it "should tell RDoc to use the given outputdir" do
      @rdoc.expects(:document).with { |args| args.include?("--op") and args.include?("myoutputdir") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/files section" do
      @rdoc.expects(:document).with { |args| args.include?("--exclude") and args.include?("/modules/[^/]*/files/.*$") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should tell RDoc to exclude all files under any modules/<mod>/templates section" do
      @rdoc.expects(:document).with { |args| args.include?("--exclude") and args.include?("/modules/[^/]*/templates/.*$") }

      Puppet::Util::RDoc.rdoc("myoutputdir", [])
    end

    it "should give all the source directories to RDoc" do
      @rdoc.expects(:document).with { |args| args.include?("sourcedir") }

      Puppet::Util::RDoc.rdoc("output", ["sourcedir"])
    end
  end

  describe "when running a manifest documentation" do
    it "should tell the parser to ignore import" do
      Puppet.expects(:[]=).with(:ignoreimport, true)

      Puppet::Util::RDoc.manifestdoc([])
    end

    it "should use a parser with the correct environment" do
      FileTest.stubs(:file?).returns(true)
      Puppet::Util::RDoc.stubs(:output)

      parser = stub_everything
      Puppet::Parser::Parser.stubs(:new).with{ |env| env.is_a?(Puppet::Node::Environment) }.returns(parser)

      parser.expects(:file=).with("file")
      parser.expects(:parse)

      Puppet::Util::RDoc.manifestdoc(["file"])
    end

    it "should puppet parse all given files" do
      FileTest.stubs(:file?).returns(true)
      Puppet::Util::RDoc.stubs(:output)

      parser = stub_everything
      Puppet::Parser::Parser.stubs(:new).returns(parser)

      parser.expects(:file=).with("file")
      parser.expects(:parse)

      Puppet::Util::RDoc.manifestdoc(["file"])
    end

    it "should call output for each parsed file" do
      FileTest.stubs(:file?).returns(true)

      ast = stub_everything
      parser = stub_everything
      Puppet::Parser::Parser.stubs(:new).returns(parser)
      parser.stubs(:parse).returns(ast)

      Puppet::Util::RDoc.expects(:output).with("file", ast)

      Puppet::Util::RDoc.manifestdoc(["file"])
    end

    describe "when outputing documentation" do
      it "should output doc for ast classes, nodes and definitions in order of increasing line number" do
        byline = sequence('documentation outputs in line order')
        Puppet::Util::RDoc.expects(:puts).with("im a class\n").in_sequence(byline)
        Puppet::Util::RDoc.expects(:puts).with("im a node\n").in_sequence(byline)
        Puppet::Util::RDoc.expects(:puts).with("im a define\n").in_sequence(byline)
        # any other output must fail
        Puppet::Util::RDoc.manifestdoc([my_fixture('basic.pp')])
      end
    end
  end
end
