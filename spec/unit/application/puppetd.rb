#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetd'
require 'puppet/network/server'

describe "puppetd" do
    before :each do
        @puppetd = Puppet::Application[:puppetd]
        @puppetd.stubs(:puts)
        @daemon = stub_everything 'daemon'
        Puppet::Daemon.stubs(:new).returns(@daemon)
        @agent = stub_everything 'agent'
        Puppet::Agent.stubs(:new).returns(@agent)
        @puppetd.run_preinit
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)

        Puppet::Node.stubs(:terminus_class=)
        Puppet::Node.stubs(:cache_class=)
        Puppet::Node::Facts.stubs(:terminus_class=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @puppetd.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @puppetd.should respond_to(:main)
    end

    it "should declare a onetime command" do
        @puppetd.should respond_to(:onetime)
    end

    it "should declare a fingerprint command" do
        @puppetd.should respond_to(:fingerprint)
    end

    it "should declare a preinit block" do
        @puppetd.should respond_to(:run_preinit)
    end

    describe "in preinit" do
        before :each do
            @puppetd.stubs(:trap)
        end

        it "should catch INT" do
            @puppetd.expects(:trap).with { |arg,block| arg == :INT }

            @puppetd.run_preinit
        end

        it "should set waitforcert to 120" do
            @puppetd.run_preinit

            @puppetd.options[:waitforcert].should == 120
        end

        it "should init client to true" do
            @puppetd.run_preinit

            @puppetd.options[:client].should be_true
        end

        it "should init fqdn to nil" do
            @puppetd.run_preinit

            @puppetd.options[:fqdn].should be_nil
        end

        it "should init serve to []" do
            @puppetd.run_preinit

            @puppetd.options[:serve].should == []
        end

        it "should use MD5 as default digest algorithm" do
            @puppetd.run_preinit

            @puppetd.options[:digest].should == :MD5
        end

        it "should not fingerprint by default" do
            @puppetd.run_preinit

            @puppetd.options[:fingerprint].should be_false
        end
    end

    describe "when handling options" do
        before do
            @old_argv = ARGV.dup
            ARGV.clear
        end

        after do
            ARGV.clear
            @old_argv.each { |a| ARGV << a }
        end

        [:centrallogging, :disable, :enable, :debug, :fqdn, :test, :verbose, :digest].each do |option|
            it "should declare handle_#{option} method" do
                @puppetd.should respond_to("handle_#{option}".to_sym)
            end

            it "should store argument value when calling handle_#{option}" do
                @puppetd.options.expects(:[]=).with(option, 'arg')
                @puppetd.send("handle_#{option}".to_sym, 'arg')
            end
        end

        it "should set an existing handler on server" do
            Puppet::Network::Handler.stubs(:handler).with("handler").returns(true)

            @puppetd.handle_serve("handler")
            @puppetd.options[:serve].should == [ :handler ]
        end

        it "should set client to false with --no-client" do
            @puppetd.handle_no_client(nil)
            @puppetd.options[:client].should be_false
        end

        it "should set onetime to ture with --onetime" do
            @puppetd.handle_onetime(nil)
            @puppetd.options[:onetime].should be_true
        end

        it "should set waitforcert to 0 with --onetime and if --waitforcert wasn't given" do
            @puppetd.explicit_waitforcert = false
            @puppetd.handle_onetime(nil)
            @puppetd.options[:waitforcert].should == 0
        end

        it "should not reset waitforcert with --onetime when --waitforcert is used" do
            @puppetd.explicit_waitforcert = true
            @puppetd.handle_onetime(nil)
            @puppetd.options[:waitforcert].should_not == 0
        end

        it "should set the log destination with --logdest" do
            @puppetd.options.stubs(:[]=).with { |opt,val| opt == :setdest }
            Puppet::Log.expects(:newdestination).with("console")

            @puppetd.handle_logdest("console")
        end

        it "should put the setdest options to true" do
            @puppetd.options.expects(:[]=).with(:setdest,true)

            @puppetd.handle_logdest("console")
        end

        it "should parse the log destination from ARGV" do
            ARGV << "--logdest" << "/my/file"

            Puppet::Util::Log.expects(:newdestination).with("/my/file")

            @puppetd.parse_options
        end

        it "should store the waitforcert options with --waitforcert" do
            @puppetd.options.expects(:[]=).with(:waitforcert,42)

            @puppetd.handle_waitforcert("42")
        end

        it "should mark explicit_waitforcert to true with --waitforcert" do
            @puppetd.options.stubs(:[]=)

            @puppetd.handle_waitforcert("42")
            @puppetd.explicit_waitforcert.should be_true
        end

        it "should set args[:Port] with --port" do
            @puppetd.handle_port("42")
            @puppetd.args[:Port].should == "42"
        end

    end

    describe "during setup" do
        before :each do
            @puppetd.options.stubs(:[])
            Puppet.stubs(:info)
            FileTest.stubs(:exists?).returns(true)
            Puppet.stubs(:[])
            Puppet.stubs(:[]).with(:libdir).returns("/dev/null/lib")
            Puppet.settings.stubs(:print_config?)
            Puppet.settings.stubs(:print_config)
            Puppet::SSL::Host.stubs(:ca_location=)
            Puppet::Transaction::Report.stubs(:terminus_class=)
            Puppet::Resource::Catalog.stubs(:terminus_class=)
            Puppet::Resource::Catalog.stubs(:cache_class=)
            Puppet::Node::Facts.stubs(:terminus_class=)
            @host = stub_everything 'host'
            Puppet::SSL::Host.stubs(:new).returns(@host)
            Puppet.stubs(:settraps)
        end

        describe "with --test" do
            before :each do
                Puppet.settings.stubs(:handlearg)
                @puppetd.options.stubs(:[]=)
            end

            it "should call setup_test" do
                @puppetd.options.stubs(:[]).with(:test).returns(true)
                @puppetd.expects(:setup_test)
                @puppetd.run_setup
            end

            it "should set options[:verbose] to true" do
                @puppetd.options.expects(:[]=).with(:verbose,true)
                @puppetd.setup_test
            end
            it "should set options[:onetime] to true" do
                @puppetd.options.expects(:[]=).with(:onetime,true)
                @puppetd.setup_test
            end
            it "should set options[:detailed_exitcodes] to true" do
                @puppetd.options.expects(:[]=).with(:detailed_exitcodes,true)
                @puppetd.setup_test
            end
            it "should set waitforcert to 0" do
                @puppetd.options.expects(:[]=).with(:waitforcert,0)
                @puppetd.setup_test
            end
        end

        it "should call setup_logs" do
            @puppetd.expects(:setup_logs)
            @puppetd.run_setup
        end

        describe "when setting up logs" do
            before :each do
                Puppet::Util::Log.stubs(:newdestination)
            end

            it "should set log level to debug if --debug was passed" do
                @puppetd.options.stubs(:[]).with(:debug).returns(true)

                Puppet::Util::Log.expects(:level=).with(:debug)

                @puppetd.setup_logs
            end

            it "should set log level to info if --verbose was passed" do
                @puppetd.options.stubs(:[]).with(:verbose).returns(true)

                Puppet::Util::Log.expects(:level=).with(:info)

                @puppetd.setup_logs
            end

            [:verbose, :debug].each do |level|
                it "should set console as the log destination with level #{level}" do
                    @puppetd.options.stubs(:[]).with(level).returns(true)

                    Puppet::Util::Log.expects(:newdestination).with(:console)

                    @puppetd.setup_logs
                end
            end

            it "should set syslog as the log destination if no --logdest" do
                @puppetd.options.stubs(:[]).with(:setdest).returns(false)

                Puppet::Util::Log.expects(:newdestination).with(:syslog)

                @puppetd.setup_logs
            end

        end

        it "should print puppet config if asked to in Puppet config" do
            @puppetd.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @puppetd.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @puppetd.run_setup }.should raise_error(SystemExit)
        end

        it "should set a central log destination with --centrallogs" do
            @puppetd.options.stubs(:[]).with(:centrallogs).returns(true)
            Puppet.stubs(:[]).with(:server).returns("puppet.reductivelabs.com")
            Puppet::Util::Log.stubs(:newdestination).with(:syslog)

            Puppet::Util::Log.expects(:newdestination).with("puppet.reductivelabs.com")

            @puppetd.run_setup
        end

        it "should use :main, :puppetd, and :ssl" do
            Puppet.settings.expects(:use).with(:main, :puppetd, :ssl)

            @puppetd.run_setup
        end

        it "should install a remote ca location" do
            Puppet::SSL::Host.expects(:ca_location=).with(:remote)

            @puppetd.run_setup
        end

        it "should install a none ca location in fingerprint mode" do
            @puppetd.options.stubs(:[]).with(:fingerprint).returns(true)
            Puppet::SSL::Host.expects(:ca_location=).with(:none)

            @puppetd.run_setup
        end

        it "should tell the report handler to use REST" do
            Puppet::Transaction::Report.expects(:terminus_class=).with(:rest)

            @puppetd.run_setup
        end

        it "should tell the catalog handler to use REST" do
            Puppet::Resource::Catalog.expects(:terminus_class=).with(:rest)

            @puppetd.run_setup
        end

        it "should tell the catalog handler to use cache" do
            Puppet::Resource::Catalog.expects(:cache_class=).with(:yaml)

            @puppetd.run_setup
        end

        it "should tell the facts to use facter" do
            Puppet::Node::Facts.expects(:terminus_class=).with(:facter)

            @puppetd.run_setup
        end

        it "should create an agent" do
            Puppet::Agent.stubs(:new).with(Puppet::Configurer)

            @puppetd.run_setup
        end

        [:enable, :disable].each do |action|
            it "should delegate to enable_disable_client if we #{action} the agent" do
                @puppetd.options.stubs(:[]).with(action).returns(true)
                @puppetd.expects(:enable_disable_client).with(@agent)

                @puppetd.run_setup
            end
        end

        describe "when enabling or disabling agent" do
            [:enable, :disable].each do |action|
                it "should call client.#{action}" do
                    @puppetd.stubs(:exit)
                    @puppetd.options.stubs(:[]).with(action).returns(true)

                    @agent.expects(action)

                    @puppetd.enable_disable_client(@agent)
                end
            end

            it "should finally exit" do
                lambda { @puppetd.enable_disable_client(@agent) }.should raise_error(SystemExit)
            end
        end

        it "should inform the daemon about our agent if :client is set to 'true'" do
            @puppetd.options.expects(:[]).with(:client).returns true
            @daemon.expects(:agent=).with(@agent)
            @puppetd.run_setup
        end

        it "should not inform the daemon about our agent if :client is set to 'false'" do
            @puppetd.options[:client] = false
            @daemon.expects(:agent=).never
            @puppetd.run_setup
        end

        it "should daemonize if needed" do
            Puppet.stubs(:[]).with(:daemonize).returns(true)

            @daemon.expects(:daemonize)

            @puppetd.run_setup
        end

        it "should wait for a certificate" do
            @puppetd.options.stubs(:[]).with(:waitforcert).returns(123)
            @host.expects(:wait_for_cert).with(123)

            @puppetd.run_setup
        end

        it "should not wait for a certificate in fingerprint mode" do
            @puppetd.options.stubs(:[]).with(:fingerprint).returns(true)
            @puppetd.options.stubs(:[]).with(:waitforcert).returns(123)
            @host.expects(:wait_for_cert).never

            @puppetd.run_setup
        end

        it "should setup listen if told to and not onetime" do
            Puppet.stubs(:[]).with(:listen).returns(true)
            @puppetd.options.stubs(:[]).with(:onetime).returns(false)

            @puppetd.expects(:setup_listen)

            @puppetd.run_setup
        end

        describe "when setting up listen" do
            before :each do
                Puppet.stubs(:[]).with(:authconfig).returns('auth')
                FileTest.stubs(:exists?).with('auth').returns(true)
                File.stubs(:exist?).returns(true)
                @puppetd.options.stubs(:[]).with(:serve).returns([])
                @puppetd.stubs(:exit)
                @server = stub_everything 'server'
                Puppet::Network::Server.stubs(:new).returns(@server)
            end


            it "should exit if no authorization file" do
                Puppet.stubs(:err)
                FileTest.stubs(:exists?).with('auth').returns(false)

                @puppetd.expects(:exit)

                @puppetd.setup_listen
            end

            it "should create a server to listen on at least the Runner handler" do
                Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers] == [:Runner] }

                @puppetd.setup_listen
            end

            it "should create a server to listen for specific handlers" do
                @puppetd.options.stubs(:[]).with(:serve).returns([:handler])
                Puppet::Network::Server.expects(:new).with { |args| args[:xmlrpc_handlers] == [:handler] }

                @puppetd.setup_listen
            end

            it "should use puppet default port" do
                Puppet.stubs(:[]).with(:puppetport).returns(:port)

                Puppet::Network::Server.expects(:new).with { |args| args[:port] == :port }

                @puppetd.setup_listen
            end
        end
    end


    describe "when running" do
        before :each do
            @puppetd.agent = @agent
            @puppetd.daemon = @daemon
            @puppetd.options.stubs(:[]).with(:fingerprint).returns(false)
        end

        it "should dispatch to fingerprint if --fingerprint is used" do
            @puppetd.options.stubs(:[]).with(:fingerprint).returns(true)

            @puppetd.get_command.should == :fingerprint
        end

        it "should dispatch to onetime if --onetime is used" do
            @puppetd.options.stubs(:[]).with(:onetime).returns(true)

            @puppetd.get_command.should == :onetime
        end

        it "should dispatch to main if --onetime and --fingerprint are not used" do
            @puppetd.options.stubs(:[]).with(:onetime).returns(false)

            @puppetd.get_command.should == :main
        end

        describe "with --onetime" do

            before :each do
                @agent.stubs(:run).returns(:report)
                @puppetd.options.stubs(:[]).with(:client).returns(:client)
                @puppetd.options.stubs(:[]).with(:detailed_exitcodes).returns(false)
                @puppetd.stubs(:exit).with(0)
                Puppet.stubs(:newservice)
            end

            it "should exit if no defined --client" do
                $stderr.stubs(:puts)
                @puppetd.options.stubs(:[]).with(:client).returns(nil)

                @puppetd.expects(:exit).with(43)

                @puppetd.onetime
            end

            it "should setup traps" do
                @daemon.expects(:set_signal_traps)

                @puppetd.onetime
            end

            it "should let the agent run" do
                @agent.expects(:run).returns(:report)

                @puppetd.onetime
            end

            it "should finish by exiting with 0 error code" do
                @puppetd.expects(:exit).with(0)

                @puppetd.onetime
            end

            describe "and --detailed-exitcodes" do
                before :each do
                    @puppetd.options.stubs(:[]).with(:detailed_exitcodes).returns(true)
                end

                it "should exit with report's computed exit status" do
                    Puppet.stubs(:[]).with(:noop).returns(false)
                    report = stub 'report', :exit_status => 666
                    @agent.stubs(:run).returns(report)
                    @puppetd.expects(:exit).with(666)

                    @puppetd.onetime
                end

                it "should always exit with 0 if --noop" do
                    Puppet.stubs(:[]).with(:noop).returns(true)
                    report = stub 'report', :exit_status => 666
                    @agent.stubs(:run).returns(report)
                    @puppetd.expects(:exit).with(0)

                    @puppetd.onetime
                end
            end
        end

        describe "with --fingerprint" do
            before :each do
                @cert = stub_everything 'cert'
                @puppetd.options.stubs(:[]).with(:fingerprint).returns(true)
                @puppetd.options.stubs(:[]).with(:digest).returns(:MD5)
                @host = stub_everything 'host'
                @puppetd.stubs(:host).returns(@host)
            end

            it "should fingerprint the certificate if it exists" do
                @host.expects(:certificate).returns(@cert)
                @cert.expects(:fingerprint).with(:MD5)
                @puppetd.fingerprint
            end

            it "should fingerprint the certificate request if no certificate have been signed" do
                @host.expects(:certificate).returns(nil)
                @host.expects(:certificate_request).returns(@cert)
                @cert.expects(:fingerprint).with(:MD5)
                @puppetd.fingerprint
            end

            it "should display the fingerprint" do
                @host.stubs(:certificate).returns(@cert)
                @cert.stubs(:fingerprint).with(:MD5).returns("DIGEST")

                Puppet.expects(:notice).with("DIGEST")

                @puppetd.fingerprint
            end
        end

        describe "without --onetime and --fingerprint" do
            before :each do
                Puppet.stubs(:notice)
                @puppetd.options.stubs(:[]).with(:client)
            end

            it "should start our daemon" do
                @daemon.expects(:start)

                @puppetd.main
            end
        end
    end
end
