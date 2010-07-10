#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }


require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
    before do
        @tty  = stub("tty",  :tty? => true )
        @pipe = stub("pipe", :tty? => false)
    end

    it "should pull off the first argument if it looks like a subcommand" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ client --help whatever.pp }, @tty )

        command_line.subcommand_name.should == "client"
        command_line.args.should            == %w{ --help whatever.pp }
    end

    it "should use 'apply' if the first argument looks like a .pp file" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.pp }, @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w{ whatever.pp }
    end

    it "should use 'apply' if the first argument looks like a .rb file" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.rb }, @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w{ whatever.rb }
    end

    it "should use 'apply' if the first argument looks like a flag" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ --debug }, @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w{ --debug }
    end

    it "should use 'apply' if the first argument is -" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ - }, @tty )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == %w{ - }
    end

    it "should return nil if the first argument is --help" do
        command_line = Puppet::Util::CommandLine.new("puppet", %w{ --help }, @tty )

        command_line.subcommand_name.should == nil
    end


    it "should return nil if there are no arguments on a tty" do
        command_line = Puppet::Util::CommandLine.new("puppet", [], @tty )

        command_line.subcommand_name.should == nil
        command_line.args.should            == []
    end

    it "should use 'apply' if there are no arguments on a pipe" do
        command_line = Puppet::Util::CommandLine.new("puppet", [], @pipe )

        command_line.subcommand_name.should == "apply"
        command_line.args.should            == []
    end

    it "should return the executable name if it is not puppet" do
        command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty )

        command_line.subcommand_name.should == "puppetmasterd"
    end

    it "should translate subcommand names into their legacy equivalent" do
        command_line = Puppet::Util::CommandLine.new("puppet", ["master"], @tty)
        command_line.legacy_executable_name.should == "puppetmasterd"
    end

    it "should leave legacy command names alone" do
        command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty)
        command_line.legacy_executable_name.should == "puppetmasterd"
    end

    describe "when the subcommand is not implemented" do
        it "should find and invoke an executable with a hyphenated name" do
            commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], @tty)
            Puppet::Util.expects(:binary).with('puppet-whatever').returns('/dev/null/puppet-whatever')
            commandline.expects(:system).with('/dev/null/puppet-whatever', 'argument')

            commandline.execute
        end

        describe "and an external implementation cannot be found" do
            it "should abort and show the usage message" do
                commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], @tty)
                Puppet::Util.expects(:binary).with('puppet-whatever').returns(nil)
                commandline.expects(:system).never

                commandline.expects(:usage_message).returns("the usage message")
                commandline.expects(:abort).with{|x| x =~ /the usage message/}.raises("stubbed abort")

                lambda{ commandline.execute }.should raise_error('stubbed abort')
            end
        end
    end
end
