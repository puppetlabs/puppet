require 'spec_helper'
require 'puppet/concurrent/lock'

describe Puppet::Concurrent::Lock do
  if Puppet::Util::Platform.jruby?
    context 'on jruby' do
      it 'synchronizes a block on itself' do
        iterations = 100
        value = 0

        lock = Puppet::Concurrent::Lock.new
        threads = iterations.times.collect do
          Thread.new do
            lock.synchronize do
              tmp = (value += 1)
              sleep(0.001)
              # This update using tmp is designed to lose increments if threads overlap
              value = tmp + 1
            end
          end
        end
        threads.each(&:join)

        # In my testing this always fails by quite a lot when not synchronized (ie on mri)
        expect(value).to eq(iterations * 2)
      end
    end
  end
end
