require 'spec_helper'
require 'puppet/face'
require 'puppet/indirector/facts/facter'
require 'puppet/indirector/facts/rest'

describe Puppet::Face[:facts, '0.0.1'] do
  describe "#find" do
    it { is_expected.to be_action :find }
  end

  describe '#upload' do
    let(:model) { Puppet::Node::Facts }
    let(:test_data) { model.new('puppet.node.test', {test_fact: 'test value'}) }
    let(:facter_terminus) { model.indirection.terminus(:facter) }

    before(:each) do
      Puppet[:facts_terminus] = :memory
      Puppet::Node::Facts.indirection.save(test_data)
      allow(Puppet::Node::Facts.indirection).to receive(:terminus_class=).with(:facter)

      Puppet.settings.parse_config(<<-CONF)
[main]
server=puppet.server.invalid
certname=puppet.node.invalid
[agent]
server=puppet.server.test
node_name_value=puppet.node.test
CONF

      # Faces start in :user run mode
      Puppet.settings.preferred_run_mode = :user
    end

    it "uploads facts as application/json" do
      stub_request(:put, 'https://puppet.server.test:8140/puppet/v3/facts/puppet.node.test?environment=*root*')
        .with(
          headers: { 'Content-Type' => 'application/json' },
          body: hash_including(
            {
              "name" => "puppet.node.test",
              "values" => {
                "test_fact" => "test value"
              }
            }
          )
        )

      subject.upload
    end

    it "passes the current environment" do
      stub_request(:put, 'https://puppet.server.test:8140/puppet/v3/facts/puppet.node.test?environment=qa')

      Puppet.override(:current_environment => Puppet::Node::Environment.remote('qa')) do
        subject.upload
      end
    end

    it "uses settings from the agent section of puppet.conf to resolve the node name" do
      stub_request(:put, /puppet.node.test/)

      subject.upload
    end

    it "logs the name of the server that received the upload" do
      stub_request(:put, 'https://puppet.server.test:8140/puppet/v3/facts/puppet.node.test?environment=*root*')

      subject.upload

      expect(@logs).to be_any {|log| log.level == :notice &&
                               log.message =~ /Uploading facts for '.*' to 'puppet\.server\.test'/}
    end
  end
end
