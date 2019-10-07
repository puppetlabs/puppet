require 'spec_helper'
require 'puppet/util/diff'
require 'puppet/util/execution'

describe Puppet::Util::Diff do
  let(:baz_output) { Puppet::Util::Execution::ProcessOutput.new('baz', 0) }

  describe ".diff" do
    it "should execute the diff command with arguments" do
      Puppet[:diff] = 'foo'
      Puppet[:diff_args] = 'bar'

      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['foo', 'bar', 'a', 'b'], {:failonfail => false, :combine => false})
        .and_return(baz_output)
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should execute the diff command with multiple arguments" do
      Puppet[:diff] = 'foo'
      Puppet[:diff_args] = 'bar qux'

      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['foo', 'bar', 'qux', 'a', 'b'], anything)
        .and_return(baz_output)
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should omit diff arguments if none are specified" do
      Puppet[:diff] = 'foo'
      Puppet[:diff_args] = ''

      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['foo', 'a', 'b'], {:failonfail => false, :combine => false})
        .and_return(baz_output)
      expect(subject.diff('a', 'b')).to eq('baz')
    end

    it "should return empty string if the diff command is empty" do
      Puppet[:diff] = ''

      expect(Puppet::Util::Execution).not_to receive(:execute)
      expect(subject.diff('a', 'b')).to eq('')
    end
  end
end
