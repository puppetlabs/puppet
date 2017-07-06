require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::API::Master::V3::Environment do
  let(:response) { Puppet::Network::HTTP::MemoryResponse.new }

  around :each do |example|
    environment = Puppet::Node::Environment.create(:production, [], '/manifests')
    loader = Puppet::Environments::Static.new(environment)
    Puppet.override(:environments => loader) do
      example.run
    end
  end

  it "returns the environment catalog" do
    request = Puppet::Network::HTTP::Request.from_hash(:headers => { 'accept' => 'application/json' }, :routing_path => "environment/production")

    subject.call(request, response)

    expect(response.code).to eq(200)

    catalog = JSON.parse(response.body)
    expect(catalog['environment']).to eq('production')
    expect(catalog['applications']).to eq({})
  end

  it "returns 404 if the environment doesn't exist" do
    request = Puppet::Network::HTTP::Request.from_hash(:routing_path => "environment/development")

    expect { subject.call(request, response) }.to raise_error(Puppet::Network::HTTP::Error::HTTPNotFoundError, /development is not a known environment/)
  end

  it "omits code_id if unspecified" do
    request = Puppet::Network::HTTP::Request.from_hash(:routing_path => "environment/production")

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to be_nil
  end

  it "includes code_id if specified" do
    request = Puppet::Network::HTTP::Request.from_hash(:params => {:code_id => '12345'}, :routing_path => "environment/production")

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to eq('12345')
  end

  it "uses code_id from the catalog if it differs from the request" do
    request = Puppet::Network::HTTP::Request.from_hash(:params => {:code_id => '12345'}, :routing_path => "environment/production")

    Puppet::Resource::Catalog.any_instance.stubs(:code_id).returns('67890')

    subject.call(request, response)

    expect(JSON.parse(response.body)['code_id']).to eq('67890')
  end
end

