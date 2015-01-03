require 'spec_helper'

require 'puppet/node/environment'
require 'puppet/network/http'
require 'matchers/json'

describe Puppet::Network::HTTP::API::Master::V3::Environments do
  include JSONMatchers

  it "responds with all of the available environments" do
    environment = Puppet::Node::Environment.create(:production, ["/first", "/second"], '/manifests')
    loader = Puppet::Environments::Static.new(environment)
    handler = Puppet::Network::HTTP::API::Master::V3::Environments.new(loader)
    response = Puppet::Network::HTTP::MemoryResponse.new

    handler.call(Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

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
    conf_stub = stub 'conf_stub'
    conf_stub.expects(:environment_timeout).returns(Float::INFINITY)
    environment = Puppet::Node::Environment.create(:production, [])
    env_loader = Puppet::Environments::Static.new(environment)
    env_loader.expects(:get_conf).with(:production).returns(conf_stub)
    handler = Puppet::Network::HTTP::API::Master::V3::Environments.new(env_loader)
    response = Puppet::Network::HTTP::MemoryResponse.new

    handler.call(Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end

  it "the response conforms to the environments schema for integer timeout" do
    conf_stub = stub 'conf_stub'
    conf_stub.expects(:environment_timeout).returns(1)
    environment = Puppet::Node::Environment.create(:production, [])
    env_loader = Puppet::Environments::Static.new(environment)
    env_loader.expects(:get_conf).with(:production).returns(conf_stub)
    handler = Puppet::Network::HTTP::API::Master::V3::Environments.new(env_loader)
    response = Puppet::Network::HTTP::MemoryResponse.new

    handler.call(Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }), response)

    expect(response.body).to validate_against('api/schemas/environments.json')
  end

end
