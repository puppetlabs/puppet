require 'spec_helper'
require_relative '../pops/parser/parser_rspec_helper'
require 'puppet/resource/capability_finder'

describe Puppet::Resource::CapabilityFinder do
  context 'when PuppetDB is not configured' do
    it 'should error' do
      expect(Puppet::Util).to receive(:const_defined?).with('Puppetdb').and_return(false)
      expect { Puppet::Resource::CapabilityFinder.find('production', nil, nil) }.to raise_error(/PuppetDB is not available/)
    end
  end

  context 'when PuppetDB is configured' do
    before(:each) do
      allow_any_instance_of(Puppet::Parser::Compiler).to receive(:loaders).and_return(loaders)
      Puppet.push_context({:loaders => loaders, :current_environment => env})
      if mock_pdb
        module Puppet::Util::Puppetdb
          def query_puppetdb(query); end
          module_function :query_puppetdb

          class Http
            def self.action(url); end
          end
        end
      end
      make_cap_type
    end

    after(:each) do
      Puppet::Util.send(:remove_const, 'Puppetdb') if mock_pdb
      Puppet::Type.rmtype(:cap)
      Puppet.pop_context()
    end

    let(:mock_pdb) { !Puppet::Util.const_defined?('Puppetdb') }
    let(:env) { Puppet::Node::Environment.create(:testing, []) }
    let(:loaders) { Puppet::Pops::Loaders.new(env) }

    let(:response_body) { [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}] }
    let(:response) { double('response', :body => response_body.to_json) }

    def make_cap_type
      Puppet::Type.newtype :cap, :is_capability => true do
        newparam :name
        newparam :host
      end
    end

    describe "when query_puppetdb method is available" do
      it 'should call use the query_puppetdb method if available' do
        expect(Puppet::Util::Puppetdb).to receive(:query_puppetdb).and_return(response_body)
        expect(Puppet::Util::Puppetdb::Http).not_to receive(:action)

        result = Puppet::Resource::CapabilityFinder.find('production', nil, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end

    describe "when query_puppetdb method is unavailable" do
      before :each do
        allow(Puppet::Util::Puppetdb).to receive(:respond_to?).with(:query_puppetdb).and_return(false)
      end

      it 'should call Puppet::Util::PuppetDB::Http.action' do
        expect(Puppet::Util::Puppetdb::Http).to receive(:action).and_return(response)
        result = Puppet::Resource::CapabilityFinder.find('production', nil, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end
    end

    describe '#find' do
      let(:capability) { Puppet::Resource.new('Cap', 'cap') }
      let(:code_id) { 'b59e5df0578ef411f773ee6c33d8073c50e7b8fe' }

      it 'should search for the resource without including code_id or environment' do
        resources = [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}}]
        allow(Puppet::Resource::CapabilityFinder).to receive(:search).with(nil, nil, capability).and_return(resources)

        result = Puppet::Resource::CapabilityFinder.find('production', code_id, Puppet::Resource.new('Cap', 'cap'))
        expect(result['host']).to eq('ahost')
      end

      it 'should return nil if no resource is found' do
        allow(Puppet::Resource::CapabilityFinder).to receive(:search).with(nil, nil, capability).and_return([])

        result = Puppet::Resource::CapabilityFinder.find('production', code_id, capability)
        expect(result).to be_nil
      end

      describe 'when multiple results are returned for different environments' do
        let(:resources) do
          [{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"ahost"}, "tags"=>["producer:production"]},
           {"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"bhost"}, "tags"=>["producer:other_env"]}]
        end

        before :each do
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with(nil, nil, capability).and_return(resources)
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
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with(nil, nil, capability).and_return(resources)
        end

        it 'should return the resource matching code_id' do
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with('production', code_id, capability).and_return([{"type"=>"Cap", "title"=>"cap", "parameters"=>{"host"=>"chost"}}])

          result = Puppet::Resource::CapabilityFinder.find('production', code_id, capability)
          expect(result['host']).to eq('chost')
        end

        it 'should fail if no resource matches code_id' do
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with('production', code_id, capability).and_return([])

          expect { Puppet::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Puppet::Error, /expected exactly one resource but got 2/)
        end

        it 'should fail if multiple resources match code_id' do
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with('production', code_id, capability).and_return(resources)

          expect { Puppet::Resource::CapabilityFinder.find('production', code_id, capability) }.to raise_error(Puppet::DevError, /expected exactly one resource but got 2/)
        end

        it 'should fail if no code_id was specified' do
          allow(Puppet::Resource::CapabilityFinder).to receive(:search).with('production', nil, capability).and_return(resources)
          expect { Puppet::Resource::CapabilityFinder.find('production', nil, capability) }.to raise_error(Puppet::DevError, /expected exactly one resource but got 2/)
        end
      end
    end
  end
end
