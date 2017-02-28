require 'puppet/state_machine'

module Puppet
  class StateMachine
    # Run a state machine until it enters a final or error state.
    #
    # This runner follows the behavior of a DFA in that the machine is run until completion or
    # error. There are two notable differences from this runner and a pure DFA. First, there
    # is no input string, and instead the state event callbacks determine the next transition.
    # Second, instead of terminating the state machine successfully if the machine is in a final
    # state when all input is consumed, entering a final state will immediately terminate the
    # machine.
    class MachineRunner
      def initialize(machine)
        @machine = machine
      end

      def call
        current = @machine.start_state
        loop do
          result = current.action

          if current.error?
            return :errored
          elsif current.final?
            return :complete
          end

          event = current.event(result)

          if event.nil?
            raise Puppet::DevError, "Cannot determine transition for state #{current.name.inspect}: no event was returned"
          end

          target_name = current.transition_for(event)

          if target_name.nil?
            raise Puppet::DevError, "State #{current.name.inspect} does not define a transition for event #{event.inspect}"
          end

          current = @machine.state(target_name)
        end
      end
    end
  end
end
