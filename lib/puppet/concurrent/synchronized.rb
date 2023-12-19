# frozen_string_literal: true

module Puppet
module Concurrent
# Including Puppet::Concurrent::Synchronized into a class when running on JRuby
# causes all of its instance methods to be synchronized on the instance itself.
# When running on MRI it has no effect.
if RUBY_PLATFORM == 'java'
  require 'jruby/synchronized'
  Synchronized = JRuby::Synchronized
else
  module Synchronized; end
end
end
end
