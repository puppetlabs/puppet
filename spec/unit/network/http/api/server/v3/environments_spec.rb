require 'spec_helper'

require 'puppet/node/environment'
require 'puppet/network/http'
require 'matchers/json'

describe Puppet::Network::HTTP::API::Server::V3::Environments do
  include JSONMatchers

  let(:environment) { Puppet::Node::Environment.create(:production, ["/first", "/second"], '/manifests') }
  let(:loader) { Puppet::Environments::Static.new(environment) }
  let(:handler) { Puppet::Network::HTTP::API::Server::V3::Environments.new(loader) }
  let(:request) { Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }) }
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  it "responds with all of the available environments" do
    handler.call(request, response)

    expect(response.code).to eq(200)
    expect(response.type).to eq("application/json")
    expect(JSON.parse(response.body)).to eq({
      "search_paths" => loader.search_paths,
      "environments" => {
        "production" => {
          "settings" => {
            "modulepath" => [File.expand_path("/first"), File.expand_path("/second")],
            "manifest" => File.expand_path("/manifests"),
            "environment_timeout" => 0,
            "config_version" => ""
          }
        }
      }
    })
  end

  it "the response conforms to the environments schema for unlimited timeout" do
    Puppet[:environment_timeout] = 'unlimited'

    handler.call(request, response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end

  it "the response conforms to the environments schema for integer timeout" do
    Puppet[:environment_timeout] = 1

    handler.call(request, response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end
end
