require 'spec_helper'
require 'puppet/face'

describe Puppet::Face[:node, '0.0.1'] do
  after :all do
    Puppet::SSL::Host.ca_location = :none
  end

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

        it "should run in master mode" do
          subject.clean('hostname')
          expect(Puppet.run_mode).to be_master
        end

        it "should set node cache as yaml" do
          expect(Puppet::Node.indirection).to receive(:terminus_class=).with(:yaml)
          expect(Puppet::Node.indirection).to receive(:cache_class=).with(:yaml)

          subject.clean('hostname')
        end

        it "should manage the certs if the host is a CA" do
          allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)
          expect(Puppet::SSL::Host).to receive(:ca_location=).with(:local)
          subject.clean('hostname')
        end

        it "should not manage the certs if the host is not a CA" do
          allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(false)
          expect(Puppet::SSL::Host).to receive(:ca_location=).with(:none)
          subject.clean('hostname')
        end
      end

      describe "when cleaning certificate" do
        before :each do
          allow(Puppet::SSL::Host).to receive(:destroy)
          @ca = double()
          allow(Puppet::SSL::CertificateAuthority).to receive(:instance).and_return(@ca)
        end

        it "should send the :destroy order to the ca if we are a CA" do
          allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(true)
          expect(@ca).to receive(:revoke).with(@host)
          expect(@ca).to receive(:destroy).with(@host)
          subject.clean_cert(@host)
        end

        it "should not destroy the certs if we are not a CA" do
          allow(Puppet::SSL::CertificateAuthority).to receive(:ca?).and_return(false)
          expect(@ca).not_to receive(:revoke)
          expect(@ca).not_to receive(:destroy)
          subject.clean_cert(@host)
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
