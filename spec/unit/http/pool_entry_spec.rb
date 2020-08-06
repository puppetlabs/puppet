require 'spec_helper'

require 'puppet/http'

describe Puppet::HTTP::PoolEntry do
  let(:connection) { double('connection') }
  let(:verifier) { double('verifier') }

  def create_session(connection, expiration_time = nil)
    expiration_time ||= Time.now + 60 * 60

    described_class.new(connection, verifier, expiration_time)
  end

  it 'provides access to its connection' do
    session = create_session(connection)

    expect(session.connection).to eq(connection)
  end

  it 'provides access to its verifier' do
    session = create_session(connection)

    expect(session.verifier).to eq(verifier)
  end

  it 'expires a connection whose expiration time is in the past' do
    now = Time.now
    past = now - 1

    session = create_session(connection, past)
    expect(session.expired?(now)).to be_truthy
  end

  it 'expires a connection whose expiration time is now' do
    now = Time.now

    session = create_session(connection, now)
    expect(session.expired?(now)).to be_truthy
  end

  it 'does not expire a connection whose expiration time is in the future' do
    now = Time.now
    future = now + 1

    session = create_session(connection, future)
    expect(session.expired?(now)).to be_falsey
  end
end
