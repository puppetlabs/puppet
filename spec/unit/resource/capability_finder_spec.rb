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

    before(:each) do
      Puppet::Parser::Compiler.any_instance.stubs(:loaders).returns(loaders)
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
    end

    describe '#find' do
      let(:capability) { Puppet::Resource.new('Cap', 'cap') }
      let(:code_id) { 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe' }

      it 'should search for the resource without including code_id or environment' do
        resources = [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}]
        Puppet::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources

        result = Puppet::Resource::CapabilityFinder.find('production', code_id, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end

      it 'should return nil if no resource is found' do
        Puppet::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns []

        result = Puppet::Resource::CapabilityFinder.find('production', code_id, capability)
        expect(result).to be_nil
      end

      describe 'when multiple results are returned for different environments' do
        let(:resources) do
          [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}, "tags"=>["producer:production"]},
           {"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"bhost"}, "tags"=>["producer:other_env"]}]
        end

        before :each do
          Puppet::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources
        end

        it 'should return the resource matching environment' do
          result = Puppet::Resource::CapabilityFinder.find('production', code_id, capability)
          expect(result['host']).to eq('ahost')
        end

        it 'should return nil if no resource matches environment' do
          result = Puppet::Resource::CapabilityFinder.find('bad_env', code_id, capability)
          expect(result).to be_nil
        end
      end

      describe 'when multiple results are returned for the same environment' do
        let(:resources) do
          [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}, "tags"=>["producer:production"]},
           {"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"bhost"}, "tags"=>["producer:production"]}]
        end

        before :each do
          Puppet::Resource::CapabilityFinder.stubs(:search).with(nil, nil, capability).returns resources
        end

        it 'should return the resource matching code_id' do
          Puppet::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"chost"}}]

          result = Puppet::Resource::CapabilityFinder.find('production', code_id, capability)
          expect(result['host']).to eq('chost')
        end

        it 'should fail if no resource matches code_id' do
          Puppet::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns []

          expect { Puppet::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Puppet::Error, /expected exactly one resource but got 2/)
        end

        it 'should fail if multiple resources match code_id' do
          Puppet::Resource::CapabilityFinder.stubs(:search).with('production', code_id, capability).returns resources

          expect { Puppet::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Puppet::DevError, /expected exactly one resource but got 2/)
        end

        it 'should fail if no code_id was specified' do
          Puppet::Resource::CapabilityFinder.stubs(:search).with('production', nil, capability).returns resources
          expect { Puppet::Resource::CapabilityFinder.find('production', nil, capability) }.to raise_error(Puppet::DevError, /expected exactly one resource but got 2/)
        end
      end
    end
  end
end
