require 'spec_helper'

describe Puppet::Type.type(:package).provider(:urpmi) do

  before do
    Puppet::Util::Execution.expects(:execute).never
    %w[rpm urpmi urpme urpmq].each do |executable|
      Puppet::Util.stubs(:which).with(executable).returns(executable)
    end
    Puppet::Util::Execution.stubs(:execute).with(['rpm', '--version'], anything).returns 'RPM version 4.9.1.3'
  end

  let(:resource) do
    Puppet::Type.type(:package).new(:name => 'foopkg', :provider => :urpmi)
  end

  before do
    subject.resource = resource
    Puppet::Type.type(:package).stubs(:defaultprovider).returns described_class
  end

  describe '#install' do
    before do
      subject.stubs(:rpm).with('-q', 'foopkg', any_parameters).returns "foopkg 0 1.2.3.4 5 noarch :DESC:\n"
    end

    describe 'without a version' do
      it 'installs the unversioned package' do
        resource[:ensure] = :present
        Puppet::Util::Execution.expects(:execute).with(['urpmi', '--auto', 'foopkg'], anything)
        subject.install
      end
    end

    describe 'with a version' do
      it 'installs the versioned package' do
        resource[:ensure] = '4.5.6'
        Puppet::Util::Execution.expects(:execute).with(['urpmi', '--auto', 'foopkg-4.5.6'], anything)
        subject.install
      end
    end

    describe "and the package install fails" do
      it "raises an error" do
        Puppet::Util::Execution.stubs(:execute).with(['urpmi', '--auto', 'foopkg'], anything)
        subject.stubs(:query)
        expect { subject.install }.to raise_error Puppet::Error, /Package \S+ was not present after trying to install it/
      end
    end
  end

  describe '#latest' do
    let(:urpmq_output) { 'foopkg : Lorem ipsum dolor sit amet, consectetur adipisicing elit ( 7.8.9-1.mga2 )' }

    it "uses urpmq to determine the latest package" do
      Puppet::Util::Execution.expects(:execute).with(['urpmq', '-S', 'foopkg'], anything).returns urpmq_output
      expect(subject.latest).to eq('7.8.9-1.mga2')
    end

    it "falls back to the current version" do
      resource[:ensure] = '5.4.3'
      Puppet::Util::Execution.expects(:execute).with(['urpmq', '-S', 'foopkg'], anything).returns ''
      expect(subject.latest).to eq('5.4.3')
    end
  end

  describe '#update' do
    it 'delegates to #install' do
      subject.expects(:install)
      subject.update
    end
  end

  describe '#purge' do
    it 'uses urpme to purge packages' do
      Puppet::Util::Execution.expects(:execute).with(['urpme', '--auto', 'foopkg'], anything)
      subject.purge
    end
  end
end
