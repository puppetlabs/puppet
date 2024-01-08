# frozen_string_literal: true

require_relative '../../puppet/concurrent/synchronized'

module Puppet
module Concurrent
# A simple lock that at the moment only does any locking on jruby
class Lock
  include Puppet::Concurrent::Synchronized
  def synchronize
    yield
  end
end
end
end
