# frozen_string_literal: true
module Puppet
  module Concurrent
    module ThreadLocalSingleton
      def singleton
        key = (name + ".singleton").intern
        thread = Thread.current
        unless thread.thread_variable?(key)
          thread.thread_variable_set(key, new)
        end
        thread.thread_variable_get(key)
      end
    end
  end
end
