#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/face'
require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
  include PuppetSpec::Files
  before do
    @tty  = stub("tty",  :tty? => true )
    @pipe = stub("pipe", :tty? => false)
  end

  it "should pull off the first argument if it looks like a subcommand" do
    command_line = Puppet::Util::CommandLine.new("puppet", %w{ client --help whatever.pp }, @tty )

    command_line.subcommand_name.should == "client"
    command_line.args.should            == %w{ --help whatever.pp }
  end

  it "should return nil if the first argument looks like a .pp file" do
    command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.pp }, @tty )

    command_line.subcommand_name.should == nil
    command_line.args.should            == %w{ whatever.pp }
  end

  it "should return nil if the first argument looks like a .rb file" do
    command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.rb }, @tty )

    command_line.subcommand_name.should == nil
    command_line.args.should            == %w{ whatever.rb }
  end

  it "should return nil if the first argument looks like a flag" do
    command_line = Puppet::Util::CommandLine.new("puppet", %w{ --debug }, @tty )

    command_line.subcommand_name.should == nil
    command_line.args.should            == %w{ --debug }
  end

  it "should return nil if the first argument is -" do
    command_line = Puppet::Util::CommandLine.new("puppet", %w{ - }, @tty )

    command_line.subcommand_name.should == nil
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

  it "should return nil if there are no arguments on a pipe" do
    command_line = Puppet::Util::CommandLine.new("puppet", [], @pipe )

    command_line.subcommand_name.should == nil
    command_line.args.should            == []
  end

  # A lot of settings management stuff has moved into command_line.rb; we need to do a first pass over
  #  all of the supplied command-line arguments before we attempt to determine what application or
  #  face we're going to run, because we need to be able to load apps/faces from the libdir
  describe "when dealing with settings" do
    let(:command_line) { Puppet::Util::CommandLine.new( "foo", [], @tty ) }

    it "should get options from Puppet.settings.optparse_addargs" do
      Puppet.settings.expects(:optparse_addargs).returns([])

      command_line.send(:parse_global_options)
    end

    it "should add Puppet.settings options to OptionParser" do
      Puppet.settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option", :NONE]])
      Puppet.settings.expects(:handlearg).with("--option", true)
      command_line.stubs(:args).returns(["--option"])
      command_line.send(:parse_global_options)
    end

    it "should not die if it sees an unrecognized option, because the app/face may handle it later" do
      command_line.stubs(:args).returns(["--topuppet", "value"])
      expect { command_line.send(:parse_global_options) } .to_not raise_error
    end

    it "should not pass an unrecognized option to Puppet.settings" do
      command_line.stubs(:args).returns(["--topuppet", "value"])
      Puppet.settings.expects(:handlearg).with("--topuppet", "value").never
      expect { command_line.send(:parse_global_options) } .to_not raise_error
    end

    it "should pass valid puppet settings options to Puppet.settings even if they appear after an unrecognized option" do
      Puppet.settings.stubs(:optparse_addargs).returns( [["--option","-o", "Funny Option", :NONE]])
      Puppet.settings.expects(:handlearg).with("--option", true)
      command_line.stubs(:args).returns(["--invalidoption", "--option"])
      command_line.send(:parse_global_options)
    end


    it "should transform boolean option to normal form for Puppet.settings" do
      Puppet.settings.expects(:handlearg).with("--option", true)
      command_line.send(:handlearg, "--[no-]option", true)
    end

    it "should transform boolean option to no- form for Puppet.settings" do
      Puppet.settings.expects(:handlearg).with("--no-option", false)
      command_line.send(:handlearg, "--[no-]option", false)
    end
  end


  describe "when dealing with puppet commands" do

    it "should return the executable name if it is not puppet" do
      command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty )

      command_line.subcommand_name.should == "puppetmasterd"
    end

    it "should translate subcommand names into their legacy equivalent" do
      command_line = Puppet::Util::CommandLine.new("puppet", ["master"], @tty)
      command_line.legacy_executable_name.should == :puppetmasterd
    end

    it "should leave legacy command names alone" do
      command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], @tty)
      command_line.legacy_executable_name.should == :puppetmasterd
    end

    describe "when the subcommand is not implemented" do
      it "should find and invoke an executable with a hyphenated name" do
        commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], @tty)
        Puppet::Util.expects(:which).with('puppet-whatever').returns('/dev/null/puppet-whatever')
        commandline.expects(:exec).with('/dev/null/puppet-whatever', 'argument')

        commandline.execute
      end

      describe "and an external implementation cannot be found" do
        it "should abort and show the usage message" do
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], @tty)
          Puppet::Util.expects(:which).with('puppet-whatever').returns(nil)
          commandline.expects(:exec).never

          expect {
            commandline.execute
          }.to have_printed(/Unknown Puppet subcommand 'whatever'/)
        end
      end
    end
    describe 'when loading commands' do
      before do
        @core_apps = %w{describe filebucket kick queue resource agent cert apply doc master}
        @command_line = Puppet::Util::CommandLine.new("foo", %w{ client --help whatever.pp }, @tty )
      end
      it "should expose available_subcommands as a class method" do
        @core_apps.each do |command|
          @command_line.available_subcommands.should include command
        end
      end
      it 'should be able to find all existing commands' do
        @core_apps.each do |command|
          @command_line.available_subcommands.should include command
        end
      end
      describe 'when multiple paths have applications' do
        before do
          @dir=tmpdir('command_line_plugin_test')
          @appdir="#{@dir}/puppet/application"
          FileUtils.mkdir_p(@appdir)
          FileUtils.touch("#{@appdir}/foo.rb")
          $LOAD_PATH.unshift(@dir) # WARNING: MUST MATCH THE AFTER ACTIONS!
        end
        it 'should be able to find commands from both paths' do
          found = @command_line.available_subcommands
          found.should include 'foo'
          @core_apps.each { |cmd| found.should include cmd }
        end
        after do
          $LOAD_PATH.shift        # WARNING: MUST MATCH THE BEFORE ACTIONS!
        end
      end
    end
  end
end
