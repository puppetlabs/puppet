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
        class Puppet::Util::Puppetdb
          class Http; end
        end
      end
      begin
        make_cap_type
        example.run
      ensure
        Puppet::Util.send(:remove_const, 'Puppetdb') if mock_pdb
      end
    end

    class MockResponse
      def body
        '[{"type": "Cap", "title": "cap", "parameters": { "host" : "ahost" }}]'
      end
    end

    def make_cap_type
      Puppet::Type.newtype :cap, :is_capability => true do
        newparam :name
        newparam :host
      end
    end

    it 'should call Puppet::Util::PuppetDB::Http.action' do
      Puppet::Util::Puppetdb::Http.expects(:action).returns(MockResponse.new)
      result = Puppet::Resource::CapabilityFinder.find('production', nil, Puppet::Resource.new('Cap', 'cap'))
      expect(result['host']).to eq('ahost')
    end

    it 'should use pass code_id in query to Puppet::Util::PuppetDB::Http.action' do
      code_id = 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe'
      Puppet::Util::Puppetdb::Http.expects(:action).with(regexp_matches(Regexp.new(CGI.escape('"=","code_id","' + code_id + "")))).returns(MockResponse.new)
      result = Puppet::Resource::CapabilityFinder.find('production', code_id, Puppet::Resource.new('Cap', 'cap'))
      expect(result['host']).to eq('ahost')
    end
  end
end
