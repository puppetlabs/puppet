module Puppet::Util
  class ExecutionStub
    class << self
      # Set a stub block that Puppet::Util::Execution.execute() should invoke instead
      # of actually executing commands on the target machine.  Intended
      # for spec testing.
      #
      # The arguments passed to the block are |command, options|, where
      # command is an array of strings and options is an options hash.
      def set(&block)
        @value = block
      end

      # Uninstall any execution stub, so that calls to
      # Puppet::Util::Execution.execute() behave normally again.
      def reset
        @value = nil
      end

      # Retrieve the current execution stub, or nil if there is no stub.
      def current_value
        @value
      end
    end
  end
end
