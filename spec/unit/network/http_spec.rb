#! /usr/bin/env ruby
require 'spec_helper'
require 'puppet/network/http'

describe Puppet::Network::HTTP do
  it 'defines an http_pool context' do
    pool = Puppet.lookup(:http_pool)
    expect(pool).to be_a(Puppet::Network::HTTP::NoCachePool)
  end
end
