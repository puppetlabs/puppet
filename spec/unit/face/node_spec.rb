require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:node, '0.0.1'] do
  describe '#cleanup' do
    it "should clean everything" do
      {
        "cert"         => ['hostname'],
        "cached_facts" => ['hostname'],
        "cached_node"  => ['hostname'],
        "reports"      => ['hostname'],
      }.each { |k, v| expect(subject).to receive("clean_#{k}".to_sym).with(*v) }
      subject.cleanup('hostname')
    end
  end

  describe 'when running #clean' do
    before :each do
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
      allow(Puppet::Node::Facts.indirection).to receive(:cache_class=)
      allow(Puppet::Node).to receive(:terminus_class=)
      allow(Puppet::Node).to receive(:cache_class=)
    end

    it 'should invoke #cleanup' do
      expect(subject).to receive(:cleanup).with('hostname')
      subject.clean('hostname')
    end
  end

  describe "clean action" do
    before :each do
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=)
      allow(Puppet::Node::Facts.indirection).to receive(:cache_class=)
      allow(Puppet::Node).to receive(:terminus_class=)
      allow(Puppet::Node).to receive(:cache_class=)
      allow(subject).to receive(:cleanup)
    end

    it "should have a clean action" do
      expect(subject).to be_action :clean
    end

    it "should not accept a call with no arguments" do
      expect { subject.clean() }.to raise_error(RuntimeError, /At least one node should be passed/)
    end

    it "should accept a node name" do
      expect { subject.clean('hostname') }.to_not raise_error
    end

    it "should accept more than one node name" do
      expect do
        subject.clean('hostname', 'hostname2', {})
      end.to_not raise_error

      expect do
        subject.clean('hostname', 'hostname2', 'hostname3')
      end.to_not raise_error
    end

    context "clean action" do
      subject { Puppet::Face[:node, :current] }
      before :each do
        allow(Puppet::Util::Log).to receive(:newdestination)
        allow(Puppet::Util::Log).to receive(:level=)
      end

      describe "during setup" do
        it "should set facts terminus and cache class to yaml" do
          expect(Puppet::Node::Facts.indirection).to receive(:terminus_class=).with(:yaml)
          expect(Puppet::Node::Facts.indirection).to receive(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should run in server mode" do
          subject.clean('hostname')
          expect(Puppet.run_mode).to be_server
        end

        it "should set node cache as yaml" do
          expect(Puppet::Node.indirection).to receive(:terminus_class=).with(:yaml)
          expect(Puppet::Node.indirection).to receive(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end
      end

      describe "when cleaning certificate", :if => Puppet.features.puppetserver_ca? do
        it "should call the CA CLI gem's clean action" do
          expect_any_instance_of(Puppetserver::Ca::Action::Clean).to receive(:run).with({ 'certnames' => ['hostname'] }).and_return(0)
          subject.clean_cert('hostname')
        end

        it "should not call the CA CLI gem's clean action if the gem is missing" do
          expect(Puppet.features).to receive(:puppetserver_ca?).and_return(false)
          expect_any_instance_of(Puppetserver::Ca::Action::Clean).not_to receive(:run)
          subject.clean_cert("hostname")
        end
      end

      describe "when cleaning cached facts" do
        it "should destroy facts" do
          @host = 'node'
          expect(Puppet::Node::Facts.indirection).to receive(:destroy).with(@host)

          subject.clean_cached_facts(@host)
        end
      end

      describe "when cleaning cached node" do
        it "should destroy the cached node" do
          expect(Puppet::Node.indirection).to receive(:destroy).with(@host)
          subject.clean_cached_node(@host)
        end
      end

      describe "when cleaning archived reports" do
        it "should tell the reports to remove themselves" do
          allow(Puppet::Transaction::Report.indirection).to receive(:destroy).with(@host)

          subject.clean_reports(@host)
        end
      end
    end
  end
end
