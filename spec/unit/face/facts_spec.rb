#! /usr/bin/env ruby
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
    let(:rest_terminus) { model.indirection.terminus(:rest) }

    before(:each) do
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

      facter_terminus.stubs(:find).with(instance_of(Puppet::Indirector::Request)).returns(test_data)
      rest_terminus.stubs(:save).with(instance_of(Puppet::Indirector::Request)).returns(nil)
    end

    it { is_expected.to be_action :upload }

    it "finds facts from terminus_class :facter" do
      facter_terminus.expects(:find).with(instance_of(Puppet::Indirector::Request)).returns(test_data)

      subject.upload
    end

    it "saves facts to terminus_class :rest" do
      rest_terminus.expects(:save).with(instance_of(Puppet::Indirector::Request)).returns(nil)

      subject.upload
    end

    it "uses settings from the agent section of puppet.conf" do
      facter_terminus.expects(:find).with(responds_with(:key, 'puppet.node.test')).returns(test_data)

      subject.upload
    end

    it "logs the name of the server that received the upload" do
      subject.upload

      expect(@logs).to be_any {|log| log.level == :notice &&
                               log.message =~ /Uploading facts for '.*' to: 'puppet\.server\.test'/}
    end
  end
end
