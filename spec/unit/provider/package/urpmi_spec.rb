require 'spec_helper'

describe Puppet::Type.type(:package).provider(:urpmi) do
  before do
    %w[rpm urpmi urpme urpmq].each do |executable|
      allow(Puppet::Util).to receive(:which).with(executable).and_return(executable)
    end
    allow(Puppet::Util::Execution).to receive(:execute)
      .with(['rpm', '--version'], anything)
      .and_return(Puppet::Util::Execution::ProcessOutput.new('RPM version 4.9.1.3', 0))
  end

  let(:resource) do
    Puppet::Type.type(:package).new(:name => 'foopkg', :provider => :urpmi)
  end

  before do
    subject.resource = resource
    allow(Puppet::Type.type(:package)).to receive(:defaultprovider).and_return(described_class)
  end

  describe '#install' do
    before do
      allow(subject).to receive(:rpm).with('-q', 'foopkg', any_args).and_return("foopkg 0 1.2.3.4 5 noarch :DESC:\n")
    end

    describe 'without a version' do
      it 'installs the unversioned package' do
        resource[:ensure] = :present
        expect(Puppet::Util::Execution).to receive(:execute).with(['urpmi', '--auto', 'foopkg'], anything)
        subject.install
      end
    end

    describe 'with a version' do
      it 'installs the versioned package' do
        resource[:ensure] = '4.5.6'
        expect(Puppet::Util::Execution).to receive(:execute).with(['urpmi', '--auto', 'foopkg-4.5.6'], anything)
        subject.install
      end
    end

    describe "and the package install fails" do
      it "raises an error" do
        allow(Puppet::Util::Execution).to receive(:execute).with(['urpmi', '--auto', 'foopkg'], anything)
        allow(subject).to receive(:query)
        expect { subject.install }.to raise_error Puppet::Error, /Package \S+ was not present after trying to install it/
      end
    end
  end

  describe '#latest' do
    let(:urpmq_output) { 'foopkg : Lorem ipsum dolor sit amet, consectetur adipisicing elit ( 7.8.9-1.mga2 )' }

    it "uses urpmq to determine the latest package" do
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['urpmq', '-S', 'foopkg'], anything)
        .and_return(Puppet::Util::Execution::ProcessOutput.new(urpmq_output, 0))
      expect(subject.latest).to eq('7.8.9-1.mga2')
    end

    it "falls back to the current version" do
      resource[:ensure] = '5.4.3'
      expect(Puppet::Util::Execution).to receive(:execute)
        .with(['urpmq', '-S', 'foopkg'], anything)
        .and_return(Puppet::Util::Execution::ProcessOutput.new('', 0))
      expect(subject.latest).to eq('5.4.3')
    end
  end

  describe '#update' do
    it 'delegates to #install' do
      expect(subject).to receive(:install)
      subject.update
    end
  end

  describe '#purge' do
    it 'uses urpme to purge packages' do
      expect(Puppet::Util::Execution).to receive(:execute).with(['urpme', '--auto', 'foopkg'], anything)
      subject.purge
    end
  end
end
