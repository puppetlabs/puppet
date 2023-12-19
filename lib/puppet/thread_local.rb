# frozen_string_literal: true

require 'concurrent'

class Puppet::ThreadLocal < Concurrent::ThreadLocalVar
end
