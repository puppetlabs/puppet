#!/usr/bin/env rspec
require 'spec_helper'

require 'puppet/node/facts'
require 'puppet/indirector/facts/couch'

describe "Puppet::Node::Facts::Couch" do
  describe "when couchdb is not available", :unless => Puppet.features.couchdb? do
    it "should fail to initialize" do
      lambda { Puppet::Node::Facts::Couch.new }.should raise_error
    end
  end

  describe "when couchdb is available", :if => Puppet.features.couchdb? do
    before do
      @mock_db = mock('couch db')
      mock_document = CouchRest::Document.new(:_id => fake_request.key, :facts => fake_request.values)
      mock_document.stubs(:database).returns(@mock_db)
      @mock_db.stubs(:get).with(fake_request.key).returns(mock_document)
      Puppet::Node::Facts::Couch.stubs(:db).returns(@mock_db)
    end

    subject { Puppet::Node::Facts::Couch }

    describe "#find" do
      describe "when the node document exists" do
        it "should find the request by key" do
          @mock_db.expects(:get).with(fake_request.key).returns({'_id' => fake_request.key, 'facts' => fake_request.instance.values})
          subject.new.find(fake_request).should == fake_request.instance
        end
      end

      describe "when the node document does not exist" do
        before do
          @mock_db.expects(:get).
            with(fake_request.key).
            raises(RestClient::ResourceNotFound)
        end

        it "should return nil" do
          subject.new.find(fake_request).should be_nil
        end

        it "should send Puppet a debug message" do
          Puppet.expects(:debug).with("No couchdb document with id: test.local")
          subject.new.find(fake_request).should be_nil
        end

      end
    end

    describe "#save" do
      describe "with options" do
        subject do
          lambda { Puppet::Node::Facts::Couch.new.save(fake_request([1])) }
        end

        it { should raise_error(ArgumentError, "PUT does not accept options") }
      end

      it "should save the json to the CouchDB database" do
        @mock_db.expects(:save_doc).at_least_once.returns({'ok' => true })
        subject.new.save(fake_request)
      end

      describe "when the document exists" do
        before do
          @doc = CouchRest::Document.new(:_id => fake_request.key, :facts => fake_request.instance.values)
          @mock_db.expects(:get).with(fake_request.key).returns(@doc)
        end

        it "saves the document" do
          @doc.expects(:save)
          subject.new.save(fake_request)
        end

      end

      describe "when the document does not exist" do
        before do
          @mock_db.expects(:get).
            with(fake_request.key).
            raises(RestClient::ResourceNotFound)
        end

        it "saves the document" do
          @mock_db.expects(:save_doc)
          subject.new.save(fake_request)
        end

      end

    end

    def fake_request(options={})
      facts = YAML.load_file(File.join(PuppetSpec::FIXTURE_DIR, 'yaml', 'test.local.yaml'))
      Struct.new(:instance, :key, :options).new(facts, facts.name, options)
    end
    private :fake_request
  end
end

