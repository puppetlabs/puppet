#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/couch'

describe Puppet::Node::Facts::Couch do
    before do
        @mock_db = mock('couch db')
        mock_document = CouchRest::Document.new(:_id => fake_request.key, :facts => fake_request.values)
        mock_document.stubs(:database).returns(@mock_db)
        @mock_db.stubs(:get).with('test.local').returns(mock_document)
        Puppet::Node::Facts::Couch.stubs(:db).returns(@mock_db)
    end

    subject { Puppet::Node::Facts::Couch }

    describe "#find" do
        it "should find the request by key" do
            @mock_db.expects(:get).with(fake_request.key).returns({'_id' => fake_request.key, 'facts' => fake_request.instance.values})
            subject.new.find(fake_request).should == fake_request.instance
        end
    end

    describe "#save" do
        it "should save the json to the CouchDB database" do
            @mock_db.expects(:save_doc).at_least_once.returns({'ok' => true })
            subject.new.save(fake_request)
        end
    end

    def fake_request
        facts = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml', 'test.local.yaml'))
        Struct.new(:instance, :key, :options).new(facts, facts.name, {})
    end
    private :fake_request

end

