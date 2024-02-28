# frozen_string_literal: true

require_relative '../../puppet/thread_local'

module Puppet
  module Pops
    # Utility class for keeping track of the "Puppet stack", ie the file
    # and line numbers of Puppet Code that created the current context.
    #
    # To use this make a call with:
    #
    # ```rb
    # Puppet::Pops::PuppetStack.stack(file, line, receiver, message, args)
    # ```
    #
    # To get the stack call:
    #
    # ```rb
    # Puppet::Pops::PuppetStack.stacktrace
    # ```
    #
    # or
    #
    # ```rb
    # Puppet::Pops::PuppetStack.top_of_stack
    # ```
    #
    # To support testing, a given file that is an empty string, or nil
    # as well as a nil line number are supported. Such stack frames
    # will be represented with the text `unknown` and `0´ respectively.
    module PuppetStack
      @stack = Puppet::ThreadLocal.new { Array.new }

      def self.stack(file, line, obj, message, args, &block)
        file = 'unknown' if file.nil? || file == ''
        line = 0 if line.nil?

        result = nil
        @stack.value.unshift([file, line])
        begin
          if block_given?
            result = obj.send(message, *args, &block)
          else
            result = obj.send(message, *args)
          end
        ensure
          @stack.value.shift()
        end
        result
      end

      def self.stacktrace
        @stack.value.dup
      end

      # Returns an Array with the top of the puppet stack, or an empty
      # Array if there was no such entry.
      def self.top_of_stack
        @stack.value.first || []
      end
    end
  end
end
