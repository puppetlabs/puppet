#!/usr/bin/env rspec
require 'spec_helper'
require 'puppet/util/diff'

describe Puppet::Util::Diff do
  describe ".diff" do
    it "should execute the diff command with arguments" do
      Puppet[:diff] = 'foo'
      Puppet[:diff_args] = 'bar'

      subject.expects(:execute).with(['foo', 'bar', 'a', 'b'], {:failonfail => false}).returns('baz')
      subject.diff('a', 'b').should == 'baz'
    end

    it "should omit diff arguments if none are specified" do
      Puppet[:diff] = 'foo'
      Puppet[:diff_args] = ''

      subject.expects(:execute).with(['foo', 'a', 'b'], {:failonfail => false}).returns('baz')
      subject.diff('a', 'b').should == 'baz'
    end

    it "should return empty string if the diff command is empty" do
      Puppet[:diff] = ''

      subject.expects(:execute).never
      subject.diff('a', 'b').should == ''
    end
  end
end
