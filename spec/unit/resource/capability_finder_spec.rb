#! /usr/bin/env ruby
require 'spec_helper'
require_relative '../pops/parser/parser_rspec_helper'
require 'puppet/resource/capability_finder'

describe Puppet::Resource::CapabilityFinder do
  context 'when PuppetDB is not configured' do
    it 'should error' do
      Puppet::Util.expects(:const_defined?).with('Puppetdb').returns false
      expect { Puppet::Resource::CapabilityFinder.find('production', nil, nil) }.to raise_error(/PuppetDB is not available/)
    end
  end

  context 'when PuppetDB is configured' do
    around(:each) do |example|
      mock_pdb = !Puppet::Util.const_defined?('Puppetdb')
      if mock_pdb
        module Puppet::Util::Puppetdb
          class Http; end
        end
      end
      begin
        Puppet::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
        Puppet.override(:loaders => loaders, :current_environment => env) do
          make_cap_type
          example.run
        end
      ensure
        Puppet::Util.send(:remove_const, 'Puppetdb') if mock_pdb
        Puppet::Type.rmtype(:cap)
        Puppet::Pops::Loaders.clear
      end
    end

    let(:env) { Puppet::Node::Environment.create(:testing, []) }
    let(:loaders) { Puppet::Pops::Loaders.new(env) }

    let(:response_body) { [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}] }
    let(:response) { stub('response', :body => response_body.to_json) }

    def make_cap_type
      Puppet::Type.newtype :cap, :is_capability => true do
        newparam :name
        newparam :host
      end
    end

    describe "when query_puppetdb method is available" do
      it 'should call use the query_puppetdb method if available' do
        Puppet::Util::Puppetdb.expects(:query_puppetdb).returns(response_body)
        Puppet::Util::Puppetdb::Http.expects(:action).never

        result = Puppet::Resource::CapabilityFinder.find('production', nil, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end

    describe "when query_puppetdb method is unavailable" do
      before :each do
        Puppet::Util::Puppetdb.stubs(:respond_to?).with(:query_puppetdb).returns false
      end

      it 'should call Puppet::Util::PuppetDB::Http.action' do
        Puppet::Util::Puppetdb::Http.expects(:action).returns(response)
        result = Puppet::Resource::CapabilityFinder.find('production', nil, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end

      it 'should include code_id in query' do
        code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
        Puppet::Util::Puppetdb::Http.expects(:action).with(regexp_matches(Regexp.new(CGI.escape('"=","code_id","' + code_id + "")))).returns(response)
        result = Puppet::Resource::CapabilityFinder.find('production', code_id, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end
  end
end
