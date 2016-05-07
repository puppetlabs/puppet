#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'
require 'puppet/network/http/api/indirected_routes'
require 'puppet/indirector_proxy'
require 'puppet_spec/files'
require 'puppet_spec/network'
require 'json'

describe Puppet::Network::HTTP::API::IndirectedRoutes do
  include PuppetSpec::Files
  include PuppetSpec::Network
  include_context 'with supported checksum types'

  describe "when running the master application" do
    before :each do
      Puppet::Application[:master].setup_terminuses
    end

    describe "using Puppet API to request file metadata" do
      let(:handler) { Puppet::Network::HTTP::API::IndirectedRoutes.new }
      let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

      with_checksum_types 'file_content', 'lib/files/file.rb' do
        before :each do
          Puppet.settings[:modulepath] = env_path
        end

        it "should find the file metadata with expected checksum" do
          request = a_request_that_finds(Puppet::IndirectorProxy.new("modules/lib/file.rb", "file_metadata"),
                                         {:accept_header => 'unknown, text/pson'},
                                         {:environment => 'production', :checksum_type => checksum_type})
          handler.call(request, response)
          resp = JSON.parse(response.body)

          expect(resp['checksum']['type']).to eq(checksum_type)
          expect(checksum_valid(checksum_type, checksum, resp['checksum']['value'])).to be_truthy
        end

        it "should search for the file metadata with expected checksum" do
          request = a_request_that_searches(Puppet::IndirectorProxy.new("modules/lib", "file_metadata"),
                                            {:accept_header => 'unknown, text/pson'},
                                            {:environment => 'production', :checksum_type => checksum_type, :recurse => 'yes'})
          handler.call(request, response)
          resp = JSON.parse(response.body)

          expect(resp.length).to eq(2)
          file = resp.find {|x| x['relative_path'] == 'file.rb'}

          expect(file['checksum']['type']).to eq(checksum_type)
          expect(checksum_valid(checksum_type, checksum, file['checksum']['value'])).to be_truthy
        end
      end
    end
  end
end
