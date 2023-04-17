# frozen_string_literal: true
require 'concurrent'

# We want to use the pure Ruby implementation even on JRuby. If we use the Java
# implementation of ThreadLocal, we end up leaking references to JRuby instances
# and preventing them from being garbage collected.
class Puppet::ThreadLocal < Concurrent::RubyThreadLocalVar
end
