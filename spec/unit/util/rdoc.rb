#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

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

        it "should install the Puppet HTML Generator into RDoc generators" do
            Puppet::Util::RDoc.rdoc("output", [])

            RDoc::RDoc::GENERATORS["puppet"].file_name.should == "puppet/util/rdoc/generators/puppet_generator.rb"
        end

        it "should tell RDoc to generate documentation using the Puppet generator" do
            @rdoc.expects(:document).with { |args| args.include?("--fmt") and args.include?("puppet") }

            Puppet::Util::RDoc.rdoc("output", [])
        end

        it "should tell RDoc to be quiet" do
            @rdoc.expects(:document).with { |args| args.include?("--quiet") }

            Puppet::Util::RDoc.rdoc("output", [])
        end

        it "should tell RDoc to force updates of indices" do
            @rdoc.expects(:document).with { |args| args.include?("--force-update") }

            Puppet::Util::RDoc.rdoc("output", [])
        end

        it "should tell RDoc to use the given outputdir" do
            @rdoc.expects(:document).with { |args| args.include?("--op") and args.include?("myoutputdir") }

            Puppet::Util::RDoc.rdoc("myoutputdir", [])
        end

        it "should tell RDoc to exclude .pp files under any modules/<mod>/files section" do
            @rdoc.expects(:document).with { |args| args.include?("--exclude") and args.include?("/modules/[^/]*/files/.*\.pp$") }

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
            before :each do
                @node = stub 'node', :file => "file", :line => 1, :doc => ""
                @class = stub 'class', :file => "file", :line => 4, :doc => ""
                @definition = stub 'definition', :file => "file", :line => 3, :doc => ""
                @ast = stub 'ast', :nodes => { :node => @node }, :hostclasses => { :class => @class }, :definitions => { :definition => @definition }
            end

            it "should output doc for ast nodes" do
                @node.expects(:doc)

                Puppet::Util::RDoc.output("file", @ast)
            end

            it "should output doc for ast classes" do
                @class.expects(:doc)

                Puppet::Util::RDoc.output("file", @ast)
            end

            it "should output doc for ast definitions" do
                @definition.expects(:doc)

                Puppet::Util::RDoc.output("file", @ast)
            end

            it "should output doc in order of increasing line number" do
                byline = sequence('byline')
                @node.expects(:doc).in_sequence(byline)
                @definition.expects(:doc).in_sequence(byline)
                @class.expects(:doc).in_sequence(byline)

                Puppet::Util::RDoc.output("file", @ast)
            end

            it "should not output documentation of ast object of another node" do
                klass = stub 'otherclass', :file => "otherfile", :line => 12, :doc => ""
                @ast.stubs(:hostclasses).returns({ :otherclass => klass })

                klass.expects(:doc).never

                Puppet::Util::RDoc.output("file", @ast)
            end

            it "should output resource documentation if needed" do
                Puppet.settings.stubs(:[]).with(:document_all).returns(true)
                [@node,@definition].each do |o|
                    o.stubs(:code).returns([])
                end

                resource = stub_everything 'resource', :line => 1
                resource.stubs(:is_a?).with(Puppet::Parser::AST::ASTArray).returns(false)
                resource.stubs(:is_a?).with(Puppet::Parser::AST::Resource).returns(true)
                @class.stubs(:code).returns([resource])

                resource.expects(:doc)

                Puppet::Util::RDoc.output("file", @ast)
            end
        end
    end
end
