#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::DummyPool do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) do
    Puppet::Network::HTTP::Site.new('https', 'rubygems.org', 443)
  end

  it 'returns a new connection' do
    pool = Puppet::Network::HTTP::DummyPool.new

    connection = stub('connection')
    factory = stub('factory', :create_connection => connection)

    expect(pool.take_connection(site, factory)).to eq(connection)
  end

  it 'has a close method' do
    Puppet::Network::HTTP::DummyPool.new.close
  end
end
