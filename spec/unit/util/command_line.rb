#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }


require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
    before do
        @tty  = stub("tty",  :tty? => true )
        @pipe = stub("pipe", :tty? => false)
    end

    it "should pull off the first argument if it looks like a subcommand" do
        args    = %w( client --help whatever.pp )
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == "client"
        args.should    == %w( --help whatever.pp )
    end

    it "should use main if the first argument looks like a .pp file" do
        args    = %w( whatever.pp )
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == "main"
        args.should    == %w( whatever.pp )
    end

    it "should use main if the first argument looks like a .rb file" do
        args    = %w( whatever.rb )
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == "main"
        args.should    == %w( whatever.rb )
    end

    it "should use main if the first argument looks like a flag" do
        args    = %w( --debug )
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == "main"
        args.should    == %w( --debug )
    end

    it "should use main if the first argument is -" do
        args    = %w( - )
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == "main"
        args.should    == %w( - )
    end

    it "should return nil if there are no arguments on a tty" do
        args    = []
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @tty )

        command.should == nil
        args.should    == []
    end

    it "should use main if there are no arguments on a pipe" do
        args    = []
        command = Puppet::Util::CommandLine.shift_subcommand_from_argv( args, @pipe )

        command.should == "main"
        args.should    == []
    end

end
