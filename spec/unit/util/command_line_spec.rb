#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/face'
require 'puppet/util/command_line'

describe Puppet::Util::CommandLine do
  include PuppetSpec::Files

  context "#initialize" do
    it "should pull off the first argument if it looks like a subcommand" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ client --help whatever.pp })

      expect(command_line.subcommand_name).to eq("client")
      expect(command_line.args).to            eq(%w{ --help whatever.pp })
    end

    it "should return nil if the first argument looks like a .pp file" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ whatever.pp })

      expect(command_line.subcommand_name).to eq(nil)
      expect(command_line.args).to            eq(%w{ whatever.pp })
    end

    it "should return nil if the first argument looks like a flag" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ --debug })

      expect(command_line.subcommand_name).to eq(nil)
      expect(command_line.args).to            eq(%w{ --debug })
    end

    it "should return nil if the first argument is -" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ - })

      expect(command_line.subcommand_name).to eq(nil)
      expect(command_line.args).to            eq(%w{ - })
    end

    it "should return nil if the first argument is --help" do
      command_line = Puppet::Util::CommandLine.new("puppet", %w{ --help })

      expect(command_line.subcommand_name).to eq(nil)
    end


    it "should return nil if there are no arguments" do
      command_line = Puppet::Util::CommandLine.new("puppet", [])

      expect(command_line.subcommand_name).to eq(nil)
      expect(command_line.args).to            eq([])
    end

    it "should pick up changes to the array of arguments" do
      args = %w{subcommand}
      command_line = Puppet::Util::CommandLine.new("puppet", args)
      args[0] = 'different_subcommand'
      expect(command_line.subcommand_name).to eq('different_subcommand')
    end
  end

  context "#execute" do
    %w{--version -V}.each do |arg|
      it "should print the version and exit if #{arg} is given" do
        expect do
          described_class.new("puppet", [arg]).execute
        end.to have_printed(/^#{Regexp.escape(Puppet.version)}$/)
      end
    end
  end

  describe "when dealing with puppet commands" do
    it "should return the executable name if it is not puppet" do
      command_line = Puppet::Util::CommandLine.new("puppetmasterd", [])
      expect(command_line.subcommand_name).to eq("puppetmasterd")
    end

    describe "when the subcommand is not implemented" do
      it "should find and invoke an executable with a hyphenated name" do
        commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'])
        Puppet::Util.expects(:which).with('puppet-whatever').
          returns('/dev/null/puppet-whatever')

        Kernel.expects(:exec).with('/dev/null/puppet-whatever', 'argument')

        commandline.execute
      end

      describe "and an external implementation cannot be found" do
        it "should abort and show the usage message" do
          Puppet::Util.expects(:which).with('puppet-whatever').returns(nil)
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'])
          commandline.expects(:exec).never

          expect {
            commandline.execute
          }.to have_printed(/Unknown Puppet subcommand 'whatever'/).and_exit_with(1)
        end

        it "should abort and show the help message" do
          Puppet::Util.expects(:which).with('puppet-whatever').returns(nil)
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'])
          commandline.expects(:exec).never

          expect {
            commandline.execute
          }.to have_printed(/See 'puppet help' for help on available puppet subcommands/).and_exit_with(1)
        end

        %w{--version -V}.each do |arg|
          it "should abort and display #{arg} information" do
            Puppet::Util.expects(:which).with('puppet-whatever').returns(nil)
            commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', arg])
            commandline.expects(:exec).never

            expect {
              commandline.execute
            }.to have_printed(%r[^#{Regexp.escape(Puppet.version)}$]).and_exit_with(1)
          end
        end
      end
    end

    describe 'when setting process priority' do
      let(:command_line) do
        Puppet::Util::CommandLine.new("puppet", %w{ agent })
      end

      before :each do
        Puppet::Util::CommandLine::ApplicationSubcommand.any_instance.stubs(:run)
      end

      it 'should never set priority by default' do
        Process.expects(:setpriority).never

        command_line.execute
      end

      it 'should lower the process priority if one has been specified' do
        Puppet[:priority] = 10

        Process.expects(:setpriority).with(0, Process.pid, 10)
        command_line.execute
      end

      it 'should warn if trying to raise priority, but not privileged user' do
        Puppet[:priority] = -10

        Process.expects(:setpriority).raises(Errno::EACCES, 'Permission denied')
        Puppet.expects(:warning).with("Failed to set process priority to '-10'")

        command_line.execute
      end

      it "should warn if the platform doesn't support `Process.setpriority`" do
        Puppet[:priority] = 15

        Process.expects(:setpriority).raises(NotImplementedError, 'NotImplementedError: setpriority() function is unimplemented on this machine')
        Puppet.expects(:warning).with("Failed to set process priority to '15'")

        command_line.execute
      end
    end
  end
end
