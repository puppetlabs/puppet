#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/provider/exec'

describe Puppet::Provider::Exec do
  describe "#extractexe" do
    it "should return the first element of an array" do
      expect(subject.extractexe(['one', 'two'])).to eq('one')
    end

    {
      # double-quoted commands
      %q{"/has whitespace"}            => "/has whitespace",
      %q{"/no/whitespace"}             => "/no/whitespace",
      # singe-quoted commands
      %q{'/has whitespace'}            => "/has whitespace",
      %q{'/no/whitespace'}             => "/no/whitespace",
      # combinations
      %q{"'/has whitespace'"}          => "'/has whitespace'",
      %q{'"/has whitespace"'}          => '"/has whitespace"',
      %q{"/has 'special' characters"}  => "/has 'special' characters",
      %q{'/has "special" characters'}  => '/has "special" characters',
      # whitespace split commands
      %q{/has whitespace}              => "/has",
      %q{/no/whitespace}               => "/no/whitespace",
    }.each do |base_command, exe|
      ['', ' and args', ' "and args"', " 'and args'"].each do |args|
        command = base_command + args
        it "should extract #{exe.inspect} from #{command.inspect}" do
          expect(subject.extractexe(command)).to eq(exe)
        end
      end
    end
  end
end
