#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/master'

describe Puppet::Application::Master do
    before :each do
        @master = Puppet::Application[:master]
        @daemon = stub_everything 'daemon'
        Puppet::Daemon.stubs(:new).returns(@daemon)
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)

        Puppet::Node.stubs(:terminus_class=)
        Puppet::Node.stubs(:cache_class=)
        Puppet::Node::Facts.stubs(:terminus_class=)
        Puppet::Node::Facts.stubs(:cache_class=)
        Puppet::Transaction::Report.stubs(:terminus_class=)
        Puppet::Resource::Catalog.stubs(:terminus_class=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @master.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @master.should respond_to(:main)
    end

    it "should declare a parseonly command" do
        @master.should respond_to(:parseonly)
    end

    it "should declare a compile command" do
        @master.should respond_to(:compile)
    end

    it "should declare a preinit block" do
        @master.should respond_to(:preinit)
    end

    describe "during preinit" do
        before :each do
            @master.stubs(:trap)
        end

        it "should catch INT" do
            @master.stubs(:trap).with { |arg,block| arg == :INT }

            @master.preinit
        end

        it "should create a Puppet Daemon" do
            Puppet::Daemon.expects(:new).returns(@daemon)

            @master.preinit
        end

        it "should give ARGV to the Daemon" do
            argv = stub 'argv'
            ARGV.stubs(:dup).returns(argv)
            @daemon.expects(:argv=).with(argv)

            @master.preinit
        end

    end

    [:debug,:verbose].each do |option|
        it "should declare handle_#{option} method" do
            @master.should respond_to("handle_#{option}".to_sym)
        end

        it "should store argument value when calling handle_#{option}" do
            @master.options.expects(:[]=).with(option, 'arg')
            @master.send("handle_#{option}".to_sym, 'arg')
        end
    end

    describe "when applying options" do
        before do
            @master.command_line.stubs(:args).returns([])
        end

        it "should set the log destination with --logdest" do
            Puppet::Log.expects(:newdestination).with("console")

            @master.handle_logdest("console")
        end

        it "should put the setdest options to true" do
            @master.options.expects(:[]=).with(:setdest,true)

            @master.handle_logdest("console")
        end

        it "should parse the log destination from ARGV" do
            @master.command_line.stubs(:args).returns(%w[--logdest /my/file])

            Puppet::Util::Log.expects(:newdestination).with("/my/file")

            @master.parse_options
        end
    end

    describe "during setup" do

        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet.stubs(:settraps)
            Puppet::Log.stubs(:level=)
            Puppet::SSL::CertificateAuthority.stubs(:instance)
            Puppet::SSL::CertificateAuthority.stubs(:ca?)
            Puppet.settings.stubs(:use)

            @master.options.stubs(:[]).with(any_parameters)
        end

        it "should set log level to debug if --debug was passed" do
            @master.options.stubs(:[]).with(:debug).returns(true)

            Puppet::Log.expects(:level=).with(:debug)

            @master.setup
        end

        it "should set log level to info if --verbose was passed" do
            @master.options.stubs(:[]).with(:verbose).returns(true)

            Puppet::Log.expects(:level=).with(:info)

            @master.setup
        end

        it "should set console as the log destination if no --logdest and --daemonize" do
            @master.stubs(:[]).with(:daemonize).returns(:false)

            Puppet::Log.expects(:newdestination).with(:syslog)

            @master.setup
        end

        it "should set syslog as the log destination if no --logdest and not --daemonize" do
            Puppet::Log.expects(:newdestination).with(:syslog)

            @master.setup
        end

        it "should set syslog as the log destination if --rack" do
            @master.options.stubs(:[]).with(:rack).returns(:true)

            Puppet::Log.expects(:newdestination).with(:syslog)

            @master.setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @master.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @master.setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @master.setup }.should raise_error(SystemExit)
        end

        it "should tell Puppet.settings to use :main,:ssl and :puppetmasterd category" do
            Puppet.settings.expects(:use).with(:main,:puppetmasterd,:ssl)

            @master.setup
        end

        it "should set node facst terminus to yaml" do
            Puppet::Node::Facts.expects(:terminus_class=).with(:yaml)

            @master.setup
        end

        it "should cache class in yaml" do
            Puppet::Node.expects(:cache_class=).with(:yaml)

            @master.setup
        end

        describe "with no ca" do

            it "should set the ca_location to none" do
                Puppet::SSL::Host.expects(:ca_location=).with(:none)

                @master.setup
            end

        end

        describe "with a ca configured" do

            before :each do
                Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)
            end

            it "should set the ca_location to local" do
                Puppet::SSL::Host.expects(:ca_location=).with(:local)

                @master.setup
            end

            it "should tell Puppet.settings to use :ca category" do
                Puppet.settings.expects(:use).with(:ca)

                @master.setup
            end

            it "should instantiate the CertificateAuthority singleton" do
                Puppet::SSL::CertificateAuthority.expects(:instance)

                @master.setup
            end


        end

    end

    describe "when running" do
        before do
            @master.preinit
        end

        it "should dispatch to parseonly if parseonly is set" do
            Puppet.stubs(:[]).with(:parseonly).returns(true)
            @master.options[:node] = nil

            @master.expects(:parseonly)
            @master.run_command
        end

        it "should dispatch to compile if called with --compile" do
            @master.options[:node] = "foo"
            @master.expects(:compile)
            @master.run_command
        end

        it "should dispatch to main if parseonly is not set" do
            Puppet.stubs(:[]).with(:parseonly).returns(false)
            @master.options[:node] = nil

            @master.expects(:main)
            @master.run_command
        end


        describe "the parseonly command" do
            before :each do
                Puppet.stubs(:[]).with(:environment)
                Puppet.stubs(:[]).with(:manifest).returns("site.pp")
                Puppet.stubs(:err)
                @master.stubs(:exit)
                @collection = stub_everything
                Puppet::Resource::TypeCollection.stubs(:new).returns(@collection)
            end

            it "should use a Puppet Resource Type Collection to parse the file" do
                @collection.expects(:perform_initial_import)
                @master.parseonly
            end

            it "should exit with exit code 0 if no error" do
                @master.expects(:exit).with(0)
                @master.parseonly
            end

            it "should exit with exit code 1 if error" do
                @collection.stubs(:perform_initial_import).raises(Puppet::ParseError)
                @master.expects(:exit).with(1)
                @master.parseonly
            end
        end

        describe "the compile command" do
            before do
                Puppet.stubs(:[]).with(:environment)
                Puppet.stubs(:[]).with(:manifest).returns("site.pp")
                Puppet.stubs(:err)
                @master.stubs(:exit)
                Puppet.features.stubs(:pson?).returns true
            end

            it "should fail if pson isn't available" do
                Puppet.features.expects(:pson?).returns false
                lambda { @master.compile }.should raise_error
            end

            it "should compile a catalog for the specified node" do
                @master.options[:node] = "foo"
                Puppet::Resource::Catalog.expects(:find).with("foo").returns Puppet::Resource::Catalog.new
                $stdout.stubs(:puts)

                @master.compile
            end

            it "should render the catalog to pson and print the output" do
                @master.options[:node] = "foo"
                catalog = Puppet::Resource::Catalog.new
                catalog.expects(:render).with(:pson).returns "mypson"
                Puppet::Resource::Catalog.expects(:find).returns catalog

                $stdout.expects(:puts).with("mypson")
                @master.compile
            end

            it "should exit with error code 30 if no catalog can be found" do
                @master.options[:node] = "foo"
                Puppet::Resource::Catalog.expects(:find).returns nil
                @master.expects(:exit).with(30)
                $stderr.expects(:puts)

                @master.compile
            end

            it "should exit with error code 30 if there's a failure" do
                @master.options[:node] = "foo"
                Puppet::Resource::Catalog.expects(:find).raises ArgumentError
                @master.expects(:exit).with(30)
                $stderr.expects(:puts)

                @master.compile
            end
        end

        describe "the main command" do
            before :each do
                @master.preinit
                @server = stub_everything 'server'
                Puppet::Network::Server.stubs(:new).returns(@server)
                @app = stub_everything 'app'
                Puppet::SSL::Host.stubs(:localhost)
                Puppet::SSL::CertificateAuthority.stubs(:ca?)
                Process.stubs(:uid).returns(1000)
                Puppet.stubs(:service)
                Puppet.stubs(:[])
                Puppet.stubs(:notice)
                Puppet.stubs(:start)
            end

            it "should create a Server" do
                Puppet::Network::Server.expects(:new)

                @master.main
            end

            it "should give the server to the daemon" do
                @daemon.expects(:server=).with(@server)

                @master.main
            end

            it "should create the server with the right XMLRPC handlers" do
                Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers] == [:Status, :FileServer, :Master, :Report, :Filebucket]}

                @master.main
            end

            it "should create the server with a :ca xmlrpc handler if needed" do
                Puppet.stubs(:[]).with(:ca).returns(true)
                Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers].include?(:CA) }

                @master.main
            end

            it "should generate a SSL cert for localhost" do
                Puppet::SSL::Host.expects(:localhost)

                @master.main
            end

            it "should make sure to *only* hit the CA for data" do
                Puppet::SSL::CertificateAuthority.stubs(:ca?).returns(true)

                Puppet::SSL::Host.expects(:ca_location=).with(:only)

                @master.main
            end

            it "should drop privileges if running as root" do
                Process.stubs(:uid).returns(0)

                Puppet::Util.expects(:chuser)

                @master.main
            end

            it "should daemonize if needed" do
                Puppet.stubs(:[]).with(:daemonize).returns(true)

                @daemon.expects(:daemonize)

                @master.main
            end

            it "should start the service" do
                @daemon.expects(:start)

                @master.main
            end

            describe "with --rack" do
                confine "Rack is not available" => Puppet.features.rack?

                before do
                    require 'puppet/network/http/rack'
                    Puppet::Network::HTTP::Rack.stubs(:new).returns(@app)
                end

                it "it should create the app with REST and XMLRPC support" do
                    @master.options.stubs(:[]).with(:rack).returns(:true)

                    Puppet::Network::HTTP::Rack.expects(:new).with { |args|
                        args[:xmlrpc_handlers] == [:Status, :FileServer, :Master, :Report, :Filebucket] and
                        args[:protocols] == [:rest, :xmlrpc]
                    }

                    @master.main
                end

                it "it should not start a daemon" do
                    @master.options.stubs(:[]).with(:rack).returns(:true)

                    @daemon.expects(:start).never

                    @master.main
                end

                it "it should return the app" do
                    @master.options.stubs(:[]).with(:rack).returns(:true)

                    app = @master.main
                    app.should equal(@app)
                end

            end

        end
    end
end
