#! /usr/bin/env ruby -S rspec
require 'spec_helper'

require 'puppet/face'
require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
  include PuppetSpec::Files
  let :tty  do stub("tty",  :tty? => true)  end
  let :pipe do stub("pipe", :tty? => false) end

  context "#initialize" do
    it "should pull off the first argument if it looks like a subcommand" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ client --help whatever.pp }, tty)

      command_line.subcommand_name.should == "client"
      command_line.args.should            == %w{ --help whatever.pp }
    end

    it "should return nil if the first argument looks like a .pp file" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.pp }, tty)

      command_line.subcommand_name.should == nil
      command_line.args.should            == %w{ whatever.pp }
    end

    it "should return nil if the first argument looks like a .rb file" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.rb }, tty)

      command_line.subcommand_name.should == nil
      command_line.args.should            == %w{ whatever.rb }
    end

    it "should return nil if the first argument looks like a flag" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ --debug }, tty)

      command_line.subcommand_name.should == nil
      command_line.args.should            == %w{ --debug }
    end

    it "should return nil if the first argument is -" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ - }, tty)

      command_line.subcommand_name.should == nil
      command_line.args.should            == %w{ - }
    end

    it "should return nil if the first argument is --help" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ --help }, tty)

      command_line.subcommand_name.should == nil
    end


    it "should return nil if there are no arguments on a tty" do
      command_line = Puppet::Util::CommandLine.new("puppet", [], tty)

      command_line.subcommand_name.should == nil
      command_line.args.should            == []
    end

    it "should return nil if there are no arguments on a pipe" do
      command_line = Puppet::Util::CommandLine.new("puppet", [], pipe)

      command_line.subcommand_name.should == nil
      command_line.args.should            == []
    end
  end

  context "#execute" do
    %w{--version -V}.each do |arg|
      it "should print the version and exit if #{arg} is given" do
        expect do
          described_class.new("puppet", [arg], tty).execute
        end.to have_printed(Puppet.version)
      end
    end
  end

  describe "when dealing with puppet commands" do
    it "should return the executable name if it is not puppet" do
      command_line = Puppet::Util::CommandLine.new("puppetmasterd", [], tty)
      command_line.subcommand_name.should == "puppetmasterd"
    end

    describe "when the subcommand is not implemented" do
      it "should find and invoke an executable with a hyphenated name" do
        commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], tty)
        Puppet::Util.expects(:which).with('puppet-whatever').
          returns('/dev/null/puppet-whatever')

        # It is important that we abort at the point exec is called, because
        # the code (reasonably) assumes that if `exec` is called processing
        # immediately terminates, and we are replaced by the executed process.
        #
        # This raise isn't a perfect simulation of that, but it is enough to
        # validate that the system works, and ... well, if exec is broken we
        # have two problems, y'know.
        commandline.expects(:exec).with('/dev/null/puppet-whatever', 'argument').
          raises(SystemExit)

        expect { commandline.execute }.to raise_error SystemExit
      end

      describe "and an external implementation cannot be found" do
        it "should abort and show the usage message" do
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'], tty)
          Puppet::Util.expects(:which).with('puppet-whatever').returns(nil)
          commandline.expects(:exec).never

          expect {
            commandline.execute
          }.to have_printed(/Unknown Puppet subcommand 'whatever'/)
        end
      end
    end
    describe 'when loading commands' do
      let :core_apps do
        %w{describe filebucket kick resource agent cert apply doc master}
      end

      let :command_line do
        Puppet::Util::CommandLine.new("foo", %w{ client --help whatever.pp }, tty)
      end

      it "should expose available_subcommands as a class method" do
        core_apps.each do |command|
          command_line.available_subcommands.should include command
        end
      end
      it 'should be able to find all existing commands' do
        core_apps.each do |command|
          command_line.available_subcommands.should include command
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
          found = command_line.available_subcommands
          found.should include 'foo'
          core_apps.each { |cmd| found.should include cmd }
        end
        after do
          $LOAD_PATH.shift        # WARNING: MUST MATCH THE BEFORE ACTIONS!
        end
      end
    end
  end
end
