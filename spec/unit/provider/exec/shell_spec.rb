#! /usr/bin/env ruby
require 'spec_helper'

describe Puppet::Type.type(:exec).provider(:shell), :unless => Puppet.features.microsoft_windows? do
  let(:resource) { Puppet::Type.type(:exec).new(:title => 'foo', :provider => 'shell') }
  let(:provider) { described_class.new(resource) }

  describe "#run" do
    it "should be able to run builtin shell commands" do
      output, status = provider.run("if [ 1 = 1 ]; then echo 'blah'; fi")
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("blah\n")
    end

    it "should be able to run commands with single quotes in them" do
      output, status = provider.run("echo 'foo  bar'")
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("foo  bar\n")
    end

    it "should be able to run commands with double quotes in them" do
      output, status = provider.run('echo "foo  bar"')
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("foo  bar\n")
    end

    it "should be able to run multiple commands separated by a semicolon" do
      output, status = provider.run("echo 'foo' ; echo 'bar'")
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("foo\nbar\n")
    end

    it "should be able to read values from the environment parameter" do
      resource[:environment] = "FOO=bar"
      output, status = provider.run("echo $FOO")
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("bar\n")
    end

    it "#14060: should interpolate inside the subshell, not outside it" do
      resource[:environment] = "foo=outer"
      output, status = provider.run("foo=inner; echo \"foo is $foo\"")
      expect(status.exitstatus).to eq(0)
      expect(output).to eq("foo is inner\n")
    end
  end

  describe "#validatecmd" do
    it "should always return true because builtins don't need path or to be fully qualified" do
      expect(provider.validatecmd('whateverdoesntmatter')).to eq(true)
    end
  end
end
