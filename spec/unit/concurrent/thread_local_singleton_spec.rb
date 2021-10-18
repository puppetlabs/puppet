require 'spec_helper'
require 'puppet/concurrent/thread_local_singleton'

class PuppetSpec::Singleton
  extend Puppet::Concurrent::ThreadLocalSingleton
end

# Use the `equal?` matcher to ensure we get the same object
describe Puppet::Concurrent::ThreadLocalSingleton do
  it 'returns the same object for a single thread' do
    expect(PuppetSpec::Singleton.singleton).to equal(PuppetSpec::Singleton.singleton)
  end

  it 'is not inherited for a newly created thread' do
    main_thread_local = PuppetSpec::Singleton.singleton
    Thread.new do
      expect(main_thread_local).to_not equal(PuppetSpec::Singleton.singleton)
    end.join
  end

  it 'does not leak outside a thread' do
    thread_local = nil
    Thread.new do
      thread_local = PuppetSpec::Singleton.singleton
    end.join
    expect(thread_local).to_not equal(PuppetSpec::Singleton.singleton)
  end

  it 'is different for each thread' do
    locals = []
    Thread.new do
      locals << PuppetSpec::Singleton.singleton
    end.join
    Thread.new do
      locals << PuppetSpec::Singleton.singleton
    end.join
    expect(locals.first).to_not equal(locals.last)
  end
end
