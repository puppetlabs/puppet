#! /usr/bin/env ruby

require 'spec_helper'

describe Puppet::Type.type(:exec).provider(:windows), :if => Puppet.features.microsoft_windows? do
  include PuppetSpec::Files

  let(:resource) { Puppet::Type.type(:exec).new(:title => 'C:\foo', :provider => :windows) }
  let(:provider) { described_class.new(resource) }

  after :all do
    # This provider may not be suitable on some machines, so we want to reset
    # the default so it isn't used by mistake in future specs.
    Puppet::Type.type(:exec).defaultprovider = nil
  end

  describe "#extractexe" do
    describe "when the command has no arguments" do
      it "should return the command if it's quoted" do
        expect(provider.extractexe('"foo"')).to eq('foo')
      end

      it "should return the command if it's quoted and contains spaces" do
        expect(provider.extractexe('"foo bar"')).to eq('foo bar')
      end

      it "should return the command if it's not quoted" do
        expect(provider.extractexe('foo')).to eq('foo')
      end
    end

    describe "when the command has arguments" do
      it "should return the command if it's quoted" do
        expect(provider.extractexe('"foo" bar baz')).to eq('foo')
      end

      it "should return the command if it's quoted and contains spaces" do
        expect(provider.extractexe('"foo bar" baz "quux quiz"')).to eq('foo bar')
      end

      it "should return the command if it's not quoted" do
        expect(provider.extractexe('foo bar baz')).to eq('foo')
      end
    end
  end

  describe "#checkexe" do
    describe "when the command is absolute", :if => Puppet.features.microsoft_windows? do
      it "should return if the command exists and is a file" do
        command = tmpfile('command')
        FileUtils.touch(command)

        expect(provider.checkexe(command)).to eq(nil)
      end
      it "should fail if the command doesn't exist" do
        command = tmpfile('command')

        expect { provider.checkexe(command) }.to raise_error(ArgumentError, "Could not find command '#{command}'")
      end
      it "should fail if the command isn't a file" do
        command = tmpfile('command')
        FileUtils.mkdir(command)

        expect { provider.checkexe(command) }.to raise_error(ArgumentError, "'#{command}' is a directory, not a file")
      end
    end

    describe "when the command is relative" do
      describe "and a path is specified" do
        before :each do
          provider.stubs(:which)
        end

        it "should search for executables with no extension" do
          provider.resource[:path] = [File.expand_path('/bogus/bin')]
          provider.expects(:which).with('foo').returns('foo')

          provider.checkexe('foo')
        end

        it "should fail if the command isn't in the path" do
          expect { provider.checkexe('foo') }.to raise_error(ArgumentError, "Could not find command 'foo'")
        end
      end

      it "should fail if no path is specified" do
        expect { provider.checkexe('foo') }.to raise_error(ArgumentError, "Could not find command 'foo'")
      end
    end
  end

  describe "#validatecmd" do
    it "should fail if the command isn't absolute and there is no path" do
      expect { provider.validatecmd('foo') }.to raise_error(Puppet::Error, /'foo' is not qualified and no path was specified/)
    end

    it "should not fail if the command is absolute and there is no path" do
      expect(provider.validatecmd('C:\foo')).to eq(nil)
    end

    it "should not fail if the command is not absolute and there is a path" do
      resource[:path] = 'C:\path;C:\another_path'

      expect(provider.validatecmd('foo')).to eq(nil)
    end
  end
end
