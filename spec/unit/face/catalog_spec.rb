require 'spec_helper'
require 'puppet/face'
require 'puppet/indirector/facts/facter'
require 'puppet/indirector/facts/rest'

describe Puppet::Face[:catalog, '0.0.1'] do

  describe '#download' do
    let(:model) { Puppet::Node::Facts }
    let(:test_data) { model.new('puppet.node.test', {test_fact: 'catalog_face_request_test_value'}) }
    let(:catalog) { Puppet::Resource::Catalog.new('puppet.node.test', Puppet::Node::Environment.remote(Puppet[:environment].to_sym)) }

    before(:each) do
      Puppet[:facts_terminus] = :memory
      Puppet::Node::Facts.indirection.save(test_data)
      allow(Puppet::Face[:catalog, "0.0.1"]).to receive(:save).once

      Puppet.settings.parse_config(<<-CONF)
[main]
server=puppet.server.test
certname=puppet.node.test
CONF

      # Faces start in :user run mode
      Puppet.settings.preferred_run_mode = :user
    end

    it "adds facts to the catalog request" do
      stub_request(:post, 'https://puppet.server.test:8140/puppet/v3/catalog/puppet.node.test?environment=*root*')
        .with(
          headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
          body: hash_including(facts: URI.encode_www_form_component(Puppet::Node::Facts.indirection.find('puppet.node.test').to_json))
        ).to_return(:status => 200, :body => catalog.render(:json), :headers => {'Content-Type' => 'application/json'})
      subject.download
    end
  end
end


