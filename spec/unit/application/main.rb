#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/main'

describe "Puppet" do
    before :each do
        @main = Puppet::Application[:main]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    [:debug,:loadclasses,:verbose,:use_nodes,:detailed_exitcodes].each do |option|
        it "should declare handle_#{option} method" do
            @main.should respond_to("handle_#{option}".to_sym)
        end

        it "should store argument value when calling handle_#{option}" do
            @main.options.expects(:[]=).with(option, 'arg')
            @main.send("handle_#{option}".to_sym, 'arg')
        end
    end

    it "should set the code to the provided code when :execute is used" do
        @main.options.expects(:[]=).with(:code, 'arg')
        @main.send("handle_execute".to_sym, 'arg')
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @main.should_parse_config?.should be_true
    end

    describe "when applying options" do

        it "should set the log destination with --logdest" do
            Puppet::Log.expects(:newdestination).with("console")

            @main.handle_logdest("console")
        end

        it "should put the logset options to true" do
            @main.options.expects(:[]=).with(:logset,true)

            @main.handle_logdest("console")
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

            @main.options.stubs(:[]).with(any_parameters)
        end

        it "should set show_diff on --noop" do
            Puppet.stubs(:[]=)
            Puppet.stubs(:[]).with(:config)
            Puppet.stubs(:[]).with(:noop).returns(true)

            Puppet.expects(:[]=).with(:show_diff, true)

            @main.run_setup
        end

        it "should set console as the log destination if logdest option wasn't provided" do
            Puppet::Log.expects(:newdestination).with(:console)

            @main.run_setup
        end

        it "should set INT trap" do
            @main.expects(:trap).with(:INT)

            @main.run_setup
        end

        it "should set log level to debug if --debug was passed" do
            @main.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @main.run_setup
        end

        it "should set log level to info if --verbose was passed" do
            @main.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @main.run_setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @main.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @main.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @main.run_setup }.should raise_error(SystemExit)
        end

    end

    describe "when executing" do

        it "should dispatch to parseonly if parseonly is set" do
            @main.stubs(:options).returns({})
            Puppet.stubs(:[]).with(:parseonly).returns(true)

            @main.get_command.should == :parseonly
        end

        it "should dispatch to 'apply' if it was called with 'apply'" do
            @main.options[:catalog] = "foo"

            @main.get_command.should == :apply
        end

        it "should dispatch to main if parseonly is not set" do
            @main.stubs(:options).returns({})
            Puppet.stubs(:[]).with(:parseonly).returns(false)

            @main.get_command.should == :main
        end

        describe "the parseonly command" do
            before :each do
                Puppet.stubs(:[]).with(:environment)
                Puppet.stubs(:[]).with(:manifest).returns("site.pp")
                @interpreter = stub_everything
                Puppet.stubs(:err)
                @main.stubs(:exit)
                @main.options.stubs(:[]).with(:code).returns "some code"
                Puppet::Parser::Interpreter.stubs(:new).returns(@interpreter)
            end

            it "should delegate to the Puppet Parser" do

                @interpreter.expects(:parser)

                @main.parseonly
            end

            it "should exit with exit code 0 if no error" do
                @main.expects(:exit).with(0)

                @main.parseonly
            end

            it "should exit with exit code 1 if error" do
                @interpreter.stubs(:parser).raises(Puppet::ParseError)

                @main.expects(:exit).with(1)

                @main.parseonly
            end

        end

        describe "the main command" do
            before :each do
                Puppet.stubs(:[])
                Puppet.settings.stubs(:use)
                Puppet.stubs(:[]).with(:prerun_command).returns ""
                Puppet.stubs(:[]).with(:postrun_command).returns ""
                Puppet.stubs(:[]).with(:trace).returns(true)

                @main.options.stubs(:[])

                @facts = stub_everything 'facts'
                Puppet::Node::Facts.stubs(:find).returns(@facts)

                @node = stub_everything 'node'
                Puppet::Node.stubs(:find).returns(@node)

                @catalog = stub_everything 'catalog'
                @catalog.stubs(:to_ral).returns(@catalog)
                Puppet::Resource::Catalog.stubs(:find).returns(@catalog)

                STDIN.stubs(:read)

                @transaction = stub_everything 'transaction'
                @catalog.stubs(:apply).returns(@transaction)

                @main.stubs(:exit)
            end

            it "should set the code to run from --code" do
                @main.options.stubs(:[]).with(:code).returns("code to run")
                Puppet.expects(:[]=).with(:code,"code to run")

                @main.main
            end

            it "should set the code to run from STDIN if no arguments" do
                ARGV.stubs(:length).returns(0)
                STDIN.stubs(:read).returns("code to run")

                Puppet.expects(:[]=).with(:code,"code to run")

                @main.main
            end

            it "should set the manifest if some files are passed on command line" do
                ARGV.stubs(:length).returns(1)
                ARGV.stubs(:shift).returns("site.pp")

                Puppet.expects(:[]=).with(:manifest,"site.pp")

                @main.main
            end

            it "should collect the node facts" do
                Puppet::Node::Facts.expects(:find).returns(@facts)

                @main.main
            end

            it "should raise an error if we can't find the node" do
                Puppet::Node::Facts.expects(:find).returns(nil)

                lambda { @puppet.main }.should raise_error
            end

            it "should find the node" do
                Puppet::Node.expects(:find).returns(@node)

                @main.main
            end

            it "should raise an error if we can't find the node" do
                Puppet::Node.expects(:find).returns(nil)

                lambda { @main.main }.should raise_error
            end

            it "should merge in our node the loaded facts" do
                @facts.stubs(:values).returns("values")

                @node.expects(:merge).with("values")

                @main.main
            end

            it "should load custom classes if loadclasses" do
                @main.options.stubs(:[]).with(:loadclasses).returns(true)
                Puppet.stubs(:[]).with(:classfile).returns("/etc/puppet/classes.txt")
                FileTest.stubs(:exists?).with("/etc/puppet/classes.txt").returns(true)
                FileTest.stubs(:readable?).with("/etc/puppet/classes.txt").returns(true)
                File.stubs(:read).with("/etc/puppet/classes.txt").returns("class")

                @node.expects(:classes=)

                @main.main
            end

            it "should compile the catalog" do
                Puppet::Resource::Catalog.expects(:find).returns(@catalog)

                @main.main
            end

            it "should transform the catalog to ral" do

                @catalog.expects(:to_ral).returns(@catalog)

                @main.main
            end

            it "should finalize the catalog" do
                @catalog.expects(:finalize)

                @main.main
            end

            it "should call the prerun and postrun commands on a Configurer instance" do
                configurer = stub 'configurer'

                Puppet::Configurer.expects(:new).returns configurer
                configurer.expects(:execute_prerun_command)
                configurer.expects(:execute_postrun_command)

                @main.main
            end

            it "should apply the catalog" do
                @catalog.expects(:apply)

                @main.main
            end

            describe "with detailed_exitcodes" do
                it "should exit with report's computed exit status" do
                    Puppet.stubs(:[]).with(:noop).returns(false)
                    @main.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
                    report = stub 'report', :exit_status => 666
                    @transaction.stubs(:report).returns(report)
                    @main.expects(:exit).with(666)

                    @main.main
                end

                it "should always exit with 0 if option is disabled" do
                    Puppet.stubs(:[]).with(:noop).returns(false)
                    @main.options.stubs(:[]).with(:detailed_exitcodes).returns(false)
                    report = stub 'report', :exit_status => 666
                    @transaction.stubs(:report).returns(report)
                    @main.expects(:exit).with(0)

                    @main.main
                end

                it "should always exit with 0 if --noop" do
                    Puppet.stubs(:[]).with(:noop).returns(true)
                    @main.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
                    report = stub 'report', :exit_status => 666
                    @transaction.stubs(:report).returns(report)
                    @main.expects(:exit).with(0)

                    @main.main
                end
            end
        end

        describe "the 'apply' command" do
            it "should read the catalog in from disk if a file name is provided" do
                @main.options[:catalog] = "/my/catalog.pson"
                File.expects(:read).with("/my/catalog.pson").returns "something"
                Puppet::Resource::Catalog.stubs(:convert_from).with(:pson,'something').returns Puppet::Resource::Catalog.new
                @main.apply
            end

            it "should read the catalog in from stdin if '-' is provided" do
                @main.options[:catalog] = "-"
                $stdin.expects(:read).returns "something"
                Puppet::Resource::Catalog.stubs(:convert_from).with(:pson,'something').returns Puppet::Resource::Catalog.new
                @main.apply
            end

            it "should deserialize the catalog from the default format" do
                @main.options[:catalog] = "/my/catalog.pson"
                File.stubs(:read).with("/my/catalog.pson").returns "something"
                Puppet::Resource::Catalog.stubs(:default_format).returns :rot13_piglatin
                Puppet::Resource::Catalog.stubs(:convert_from).with(:rot13_piglatin,'something').returns Puppet::Resource::Catalog.new
                @main.apply
            end

            it "should fail helpfully if deserializing fails" do
                @main.options[:catalog] = "/my/catalog.pson"
                File.stubs(:read).with("/my/catalog.pson").returns "something syntacically invalid"
                lambda { @main.apply }.should raise_error(Puppet::Error)
            end

            it "should convert plain data structures into a catalog if deserialization does not do so" do
                @main.options[:catalog] = "/my/catalog.pson"
                File.stubs(:read).with("/my/catalog.pson").returns "something"
                Puppet::Resource::Catalog.stubs(:convert_from).with(:pson,"something").returns({:foo => "bar"})
                Puppet::Resource::Catalog.expects(:pson_create).with({:foo => "bar"}).returns(Puppet::Resource::Catalog.new)
                @main.apply
            end

            it "should convert the catalog to a RAL catalog and use a Configurer instance to apply it" do
                @main.options[:catalog] = "/my/catalog.pson"
                File.stubs(:read).with("/my/catalog.pson").returns "something"
                catalog = Puppet::Resource::Catalog.new
                Puppet::Resource::Catalog.stubs(:convert_from).with(:pson,'something').returns catalog
                catalog.expects(:to_ral).returns "mycatalog"

                configurer = stub 'configurer'
                Puppet::Configurer.expects(:new).returns configurer
                configurer.expects(:run).with(:catalog => "mycatalog")

                @main.apply
            end
        end
    end
end
