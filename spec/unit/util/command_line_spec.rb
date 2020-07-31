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
        end.to output(/^#{Regexp.escape(Puppet.version)}$/).to_stdout
      end
    end

    %w{--help -h help}.each do|arg|
      it "should print help and exit if #{arg} is given" do
        commandline = Puppet::Util::CommandLine.new("puppet", [arg])
        expect(commandline).not_to receive(:exec)

        expect {
          commandline.execute
        }.to exit_with(0)
         .and output(/Usage: puppet <subcommand> \[options\] <action> \[options\]/).to_stdout
      end
    end

    it "should fail if the config file isn't readable and we're running a subcommand that requires a readable config file" do
      allow(Puppet::FileSystem).to receive(:exist?).with(Puppet[:config]).and_return(true)
      allow_any_instance_of(Puppet::Settings).to receive(:read_file).and_return('')
      expect_any_instance_of(Puppet::Settings).to receive(:read_file).with(Puppet[:config]).and_raise('Permission denied')

      expect{ described_class.new("puppet", ['config']).execute }.to raise_error(SystemExit)
    end

    it "should not fail if the config file isn't readable and we're running a subcommand that does not require a readable config file" do
      allow(Puppet::FileSystem).to receive(:exist?)
      allow(Puppet::FileSystem).to receive(:exist?).with(Puppet[:config]).and_return(true)
      allow_any_instance_of(Puppet::Settings).to receive(:read_file).and_return('')
      expect_any_instance_of(Puppet::Settings).to receive(:read_file).with(Puppet[:config]).and_raise('Permission denied')

      commandline = described_class.new("puppet", ['help'])

      expect {
        commandline.execute
      }.to exit_with(0)
       .and output(/Usage: puppet <subcommand> \[options\] <action> \[options\]/).to_stdout
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
        expect(Puppet::Util).to receive(:which).with('puppet-whatever').
          and_return('/dev/null/puppet-whatever')

        expect(Kernel).to receive(:exec).with('/dev/null/puppet-whatever', 'argument')

        commandline.execute
      end

      describe "and an external implementation cannot be found" do
        it "should abort and show the usage message" do
          expect(Puppet::Util).to receive(:which).with('puppet-whatever').and_return(nil)
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'])
          expect(commandline).not_to receive(:exec)

          expect {
            commandline.execute
          }.to exit_with(1)
           .and output(/Unknown Puppet subcommand 'whatever'/).to_stdout
        end

        it "should abort and show the help message" do
          expect(Puppet::Util).to receive(:which).with('puppet-whatever').and_return(nil)
          commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', 'argument'])
          expect(commandline).not_to receive(:exec)

          expect {
            commandline.execute
          }.to exit_with(1)
           .and output(/See 'puppet help' for help on available puppet subcommands/).to_stdout
        end

        %w{--version -V}.each do |arg|
          it "should abort and display #{arg} information" do
            expect(Puppet::Util).to receive(:which).with('puppet-whatever').and_return(nil)
            commandline = Puppet::Util::CommandLine.new("puppet", ['whatever', arg])
            expect(commandline).not_to receive(:exec)

            expect {
              commandline.execute
            }.to exit_with(1)
             .and output(%r[^#{Regexp.escape(Puppet.version)}$]).to_stdout
          end
        end
      end
    end

    describe 'when setting process priority' do
      let(:command_line) do
        Puppet::Util::CommandLine.new("puppet", %w{ agent })
      end

      before :each do
        allow_any_instance_of(Puppet::Util::CommandLine::ApplicationSubcommand).to receive(:run)
      end

      it 'should never set priority by default' do
        expect(Process).not_to receive(:setpriority)

        command_line.execute
      end

      it 'should lower the process priority if one has been specified' do
        Puppet[:priority] = 10

        expect(Process).to receive(:setpriority).with(0, Process.pid, 10)
        command_line.execute
      end

      it 'should warn if trying to raise priority, but not privileged user' do
        Puppet[:priority] = -10

        expect(Process).to receive(:setpriority).and_raise(Errno::EACCES, 'Permission denied')
        expect(Puppet).to receive(:warning).with("Failed to set process priority to '-10'")

        command_line.execute
      end

      it "should warn if the platform doesn't support `Process.setpriority`" do
        Puppet[:priority] = 15

        expect(Process).to receive(:setpriority).and_raise(NotImplementedError, 'NotImplementedError: setpriority() function is unimplemented on this machine')
        expect(Puppet).to receive(:warning).with("Failed to set process priority to '15'")

        command_line.execute
      end
    end
  end
end
