#! /usr/bin/env ruby
require 'spec_helper'

require 'puppet/network/http'

describe Puppet::Network::HTTP::Session do
  let(:connection) { stub('connection') }

  def create_session(connection, expiration_time = nil)
    expiration_time ||= Time.now + 60 * 60

    Puppet::Network::HTTP::Session.new(connection, expiration_time)
  end

  it 'provides access to its connection' do
    session = create_session(connection)

    session.connection.should == connection
  end

  it 'expires a connection whose expiration time is in the past' do
    now = Time.now
    past = now - 1

    session = create_session(connection, past)
    session.expired?(now).should be_true
  end

  it 'expires a connection whose expiration time is now' do
    now = Time.now

    session = create_session(connection, now)
    session.expired?(now).should be_true
  end

  it 'does not expire a connection whose expiration time is in the future' do
    now = Time.now
    future = now + 1

    session = create_session(connection, future)
    session.expired?(now).should be_false
  end
end
