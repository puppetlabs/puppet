#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP::Factory do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) { Puppet::Network::HTTP::Site.new('https', 'www.example.com', 443) }
  def create_connection(site)
    factory = Puppet::Network::HTTP::Factory.new

    factory.create_connection(site)
  end

  it 'creates a connection for the site' do
    conn = create_connection(site)

    expect(conn.use_ssl?).to be_true
    expect(conn.address).to eq(site.host)
    expect(conn.port).to eq(site.port)
  end

  it 'creates a connection that has not yet been started' do
    conn = create_connection(site)

    expect(conn).to_not be_started
  end

  it 'creates a connection supporting at least HTTP 1.1' do
    conn = create_connection(site)

    expect(any_of(conn.class.version_1_1?, conn.class.version_1_1?)).to be_true
  end
end
