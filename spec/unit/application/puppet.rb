#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppet'

describe "Puppet" do
    before :each do
        @puppet = Puppet::Application[:puppet]
    end

    it "should declare a version option" do
        @puppet.should respond_to(:handle_version)
    end

    [:debug,:execute,:loadclasses,:verbose,:use_nodes,:detailed_exitcodes].each do |option|
        it "should declare handle_#{option} method" do
            @puppet.should respond_to("handle_#{option}".to_sym)
        end

        it "should store argument value when calling handle_#{option}" do
            @puppet.options.expects(:[]=).with(option, 'arg')
            @puppet.send("handle_#{option}".to_sym, 'arg')
        end
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @puppet.should_parse_config?.should be_true
    end

    describe "when applying options" do
        it "should exit after printing the version" do
            @puppet.stubs(:puts)

            lambda { @puppet.handle_version(nil) }.should raise_error(SystemExit)
        end

        it "should set the log destination with --logdest" do
            Puppet::Log.expects(:newdestination).with("console")

            @puppet.handle_logdest("console")
        end

        it "should put the logset options to true" do
            @puppet.options.expects(:[]=).with(:logset,true)

            @puppet.handle_logdest("console")
        end
    end

    describe "during setup" do

        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet.stubs(:trap)
            Puppet::Log.stubs(:level=)
            Puppet.stubs(:parse_config)
            Puppet::Network::Client.dipper.stubs(:new)
            STDIN.stubs(:read)

            @puppet.options.stubs(:[]).with(any_parameters)
        end

        it "should parse additionnal Puppet config if set to" do
            Puppet.stubs(:[]).with(:noop)
            Puppet.stubs(:[]).with(:config).returns("file.conf")
            File.stubs(:exists?).with("file.conf").returns(true)

            Puppet.settings.expects(:parse).with("file.conf")

            @puppet.run_setup
        end

        it "should set show_diff on --noop" do
            Puppet.stubs(:[]=)
            Puppet.stubs(:[]).with(:config)
            Puppet.stubs(:[]).with(:noop).returns(true)

            Puppet.expects(:[]=).with(:show_diff, true)

            @puppet.run_setup
        end

        it "should set console as the log destination if logdest option wasn't provided" do
            Puppet::Log.expects(:newdestination).with(:console)

            @puppet.run_setup
        end

        it "should set INT trap" do
            @puppet.expects(:trap).with(:INT)

            @puppet.run_setup
        end

        it "should set log level to debug if --debug was passed" do
            @puppet.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @puppet.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @puppet.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @puppet.run_setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @puppet.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @puppet.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @puppet.run_setup }.should raise_error(SystemExit)
        end

        it "should set the code to run from --code" do
            @puppet.options.stubs(:[]).with(:code).returns("code to run")
            Puppet.expects(:[]=).with(:code,"code to run")

            @puppet.run_setup
        end

        it "should set the code to run from STDIN if no arguments" do
            ARGV.stubs(:length).returns(0)
            STDIN.stubs(:read).returns("code to run")

            Puppet.expects(:[]=).with(:code,"code to run")

            @puppet.run_setup
        end

        it "should set the manifest if some files are passed on command line" do
            ARGV.stubs(:length).returns(1)
            ARGV.stubs(:shift).returns("site.pp")

            Puppet.expects(:[]=).with(:manifest,"site.pp")

            @puppet.run_setup
        end

    end

    describe "when executing" do

        it "should dispatch to parseonly if parseonly is set" do
            Puppet.stubs(:[]).with(:parseonly).returns(true)

            @puppet.get_command.should == :parseonly
        end

        it "should dispatch to main if parseonly is not set" do
            Puppet.stubs(:[]).with(:parseonly).returns(false)

            @puppet.get_command.should == :main
        end

        describe "the parseonly command" do
            before :each do
                Puppet.stubs(:[]).with(:environment)
                Puppet.stubs(:[]).with(:manifest).returns("site.pp")
                @interpreter = stub_everything
                Puppet.stubs(:err)
                @puppet.stubs(:exit)
                Puppet::Parser::Interpreter.stubs(:new).returns(@interpreter)
            end

            it "should delegate to the Puppet Parser" do

                @interpreter.expects(:parser)

                @puppet.parseonly
            end

            it "should exit with exit code 0 if no error" do
                @puppet.expects(:exit).with(0)

                @puppet.parseonly
            end

            it "should exit with exit code 1 if error" do
                @interpreter.stubs(:parser).raises(Puppet::ParseError)

                @puppet.expects(:exit).with(1)

                @puppet.parseonly
            end

        end

        describe "the main command" do
            before :each do
                Puppet.stubs(:[])
                Puppet.stubs(:[]).with(:trace).returns(true)

                @puppet.options.stubs(:[])

                @facts = stub_everything 'facts'
                Puppet::Node::Facts.stubs(:find).returns(@facts)

                @node = stub_everything 'node'
                Puppet::Node.stubs(:find).returns(@node)

                @catalog = stub_everything 'catalog'
                @catalog.stubs(:to_ral).returns(@catalog)
                Puppet::Resource::Catalog.stubs(:find).returns(@catalog)

                @transaction = stub_everything 'transaction'
                @catalog.stubs(:apply).returns(@transaction)

                @puppet.stubs(:exit)
            end

            it "should collect the node facts" do
                Puppet::Node::Facts.expects(:find).returns(@facts)

                @puppet.main
            end

            it "should find the node" do
                Puppet::Node.expects(:find).returns(@node)

                @puppet.main
            end

            it "should raise an error if we can't find the node" do
                Puppet::Node.expects(:find).returns(nil)

                lambda { @puppet.main }.should raise_error
            end

            it "should merge in our node the loaded facts" do
                @facts.stubs(:values).returns("values")

                @node.expects(:merge).with("values")

                @puppet.main
            end

            it "should load custom classes if loadclasses" do
                @puppet.options.stubs(:[]).with(:loadclasses).returns(true)
                Puppet.stubs(:[]).with(:classfile).returns("/etc/puppet/classes.txt")
                FileTest.stubs(:exists?).with("/etc/puppet/classes.txt").returns(true)
                FileTest.stubs(:readable?).with("/etc/puppet/classes.txt").returns(true)
                File.stubs(:read).with("/etc/puppet/classes.txt").returns("class")

                @node.expects(:classes=)

                @puppet.main
            end

            it "should compile the catalog" do
                Puppet::Resource::Catalog.expects(:find).returns(@catalog)

                @puppet.main
            end

            it "should transform the catalog to ral" do

                @catalog.expects(:to_ral).returns(@catalog)

                @puppet.main
            end

            it "should finalize the catalog" do
                @catalog.expects(:finalize)

                @puppet.main
            end

            it "should apply the catalog" do
                @catalog.expects(:apply)

                @puppet.main
            end

            it "should generate a report if not noop" do
                Puppet.stubs(:[]).with(:noop).returns(false)
                @puppet.options.stubs(:[]).with(:detailed_exits).returns(true)
                metrics = stub 'metrics', :[] => { :total => 10, :failed => 0}
                report = stub 'report', :metrics => metrics
                @transaction.stubs(:report).returns(report)

                @transaction.expects(:generate_report)

                @puppet.main
            end

        end
    end

end