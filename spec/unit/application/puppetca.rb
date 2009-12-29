#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/application/puppetca'

describe "PuppetCA" do
    before :each do
        @puppetca = Puppet::Application[:puppetca]
        Puppet::Util::Log.stubs(:newdestination)
        Puppet::Util::Log.stubs(:level=)
    end

    it "should ask Puppet::Application to parse Puppet configuration file" do
        @puppetca.should_parse_config?.should be_true
    end

    it "should declare a main command" do
        @puppetca.should respond_to(:main)
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject{ |m| m == :destroy }.each do |method|
        it "should declare option --#{method}" do
            @puppetca.should respond_to("handle_#{method}".to_sym)
        end
    end

    it "should set log level to info with the --verbose option" do

        Puppet::Log.expects(:level=).with(:info)

        @puppetca.handle_verbose(0)
    end

    it "should set log level to debug with the --debug option" do

        Puppet::Log.expects(:level=).with(:debug)

        @puppetca.handle_debug(0)
    end

    it "should set the fingerprint digest with the --digest option" do
        @puppetca.handle_digest(:digest)

        @puppetca.digest.should == :digest
    end

    it "should set mode to :destroy for --clean" do
        @puppetca.handle_clean(0)
        @puppetca.mode.should == :destroy
    end

    it "should set all to true for --all" do
        @puppetca.handle_all(0)
        @puppetca.all.should be_true
    end

    Puppet::SSL::CertificateAuthority::Interface::INTERFACE_METHODS.reject { |m| m == :destroy }.each do |method|
        it "should set mode to #{method} with option --#{method}" do
            @puppetca.send("handle_#{method}".to_sym, nil)

            @puppetca.mode.should == method
        end
    end

    describe "during setup" do

        before :each do
            Puppet::Log.stubs(:newdestination)
            Puppet::SSL::Host.stubs(:ca_location=)
            Puppet::SSL::CertificateAuthority.stubs(:new)
        end

        it "should set console as the log destination" do
            Puppet::Log.expects(:newdestination).with(:console)

            @puppetca.run_setup
        end

        it "should print puppet config if asked to in Puppet config" do
            @puppetca.stubs(:exit)
            Puppet.settings.stubs(:print_configs?).returns(true)

            Puppet.settings.expects(:print_configs)

            @puppetca.run_setup
        end

        it "should exit after printing puppet config if asked to in Puppet config" do
            Puppet.settings.stubs(:print_configs?).returns(true)

            lambda { @puppetca.run_setup }.should raise_error(SystemExit)
        end

        it "should set the CA location to 'only'" do
            Puppet::SSL::Host.expects(:ca_location=).with(:only)

            @puppetca.run_setup
        end

        it "should create a new certificate authority" do
            Puppet::SSL::CertificateAuthority.expects(:new)

            @puppetca.run_setup
        end
    end

    describe "when running" do
        before :each do
            @puppetca.all = false
            @ca = stub_everything 'ca'
            @puppetca.ca = @ca
            ARGV.stubs(:collect).returns([])
        end

        it "should delegate to the CertificateAuthority" do
            @ca.expects(:apply)

            @puppetca.main
        end

        it "should delegate with :all if option --all was given" do
            @puppetca.handle_all(0)

            @ca.expects(:apply).with { |mode,to| to[:to] == :all }

            @puppetca.main
        end

        it "should delegate to ca.apply with the hosts given on command line" do
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| to[:to] == ["host"]}

            @puppetca.main
        end

        it "should send the currently set digest" do
            ARGV.stubs(:collect).returns(["host"])
            @puppetca.handle_digest(:digest)

            @ca.expects(:apply).with { |mode,to| to[:digest] == :digest}

            @puppetca.main
        end

        it "should delegate to ca.apply with current set mode" do
            @puppetca.mode = "currentmode"
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == "currentmode" }

            @puppetca.main
        end

        it "should revoke cert if mode is clean" do
            @puppetca.mode = :destroy
            ARGV.stubs(:collect).returns(["host"])

            @ca.expects(:apply).with { |mode,to| mode == :revoke }
            @ca.expects(:apply).with { |mode,to| mode == :destroy }

            @puppetca.main
        end

    end
end
