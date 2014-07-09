#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'
require 'puppet/ssl'

describe Puppet::Network::HTTP::Factory do
  before :each do
    Puppet::SSL::Key.indirection.terminus_class = :memory
    Puppet::SSL::CertificateRequest.indirection.terminus_class = :memory
  end

  let(:site) { Puppet::Network::HTTP::Site.new('https', 'www.example.com', 443) }

  def create_connection(site)
    verifier = Puppet::SSL::Validator::DefaultValidator.new
    factory = Puppet::Network::HTTP::Factory.new(verifier)

    factory.create_connection(site)
  end

  it 'creates connections for our site' do
    conn = create_connection(site)

    expect(conn.use_ssl?).to be_true
    expect(conn.address).to eq(site.host)
    expect(conn.port).to eq(site.port)
  end

  it 'creates connections that have not yet started' do
    conn = create_connection(site)

    expect(conn).to_not be_started
  end
end
