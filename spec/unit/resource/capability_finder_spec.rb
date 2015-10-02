#! /usr/bin/env ruby
require 'spec_helper'
require_relative '../pops/parser/parser_rspec_helper'
require 'puppet/resource/capability_finder'

describe Puppet::Resource::CapabilityFinder do
  it 'should error unless the PuppetDB is configured' do
    expect { Puppet::Resource::CapabilityFinder.find('production', nil) }.to raise_error(/PuppetDB is not available/)
  end

  def make_cap_type
    Puppet::Type.newtype :cap, :is_capability => true do
      newparam :name
      newparam :host
    end
  end

  it 'should call Puppet::Util::PuppetDB::Http.action' do
    make_cap_type
    cap = Puppet::Resource.new('Cap', 'cap')

    class MockResponse
      def body
        '[{"type": "Cap", "title": "cap", "parameters": { "host" : "ahost" }}]'
      end
    end

    unless Puppet::Util.const_defined?('Puppetdb')
      class Puppet::Util::Puppetdb
        class Http; end
      end
    end

    Puppet::Util::Puppetdb::Http.expects(:action).returns(MockResponse.new)
    result = Puppet::Resource::CapabilityFinder.find('production', cap)
    expect(result['host']).to eq('ahost')
  end
end
