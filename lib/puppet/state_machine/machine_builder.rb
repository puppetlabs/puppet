require 'puppet/state_machine/state'

module Puppet
  class StateMachine
    # The MachineBuilder class provides a DSL for implementing the states and transitions of a state machine,
    # and validating that the machine is well behaved.
    class MachineBuilder
      # @param machine_name [String] The name of the machine to build.
      def initialize(machine_name)
        @machine_name = machine_name
        @states = {}
        @start_state = nil
      end

      # Build and verify a new state machine.
      # @return [Puppet::StateMachine]
      def build(&blk)
        yield self
        verify!
        Puppet::StateMachine.new(@machine_name, @states, @start_state)
      end

      # Compose multiple state machines into a a single state machine.
      #
      # @example
      #   machine.compose({m1: machine1, m2: machine2}) do |m|
      #     m.start_state([:m1, :start])
      #
      #     m.transition(
      #       source: [:m1, :final],
      #       target: [:m2, :start],
      #       on: Puppet::StateMachine::FINAL_EVENT)
      #
      #     m.final([:m2, :final])
      #   end
      def compose(machines, &blk)
        machines.each_pair do |ns, machine|
          @states.merge!(machine.namespace_states(ns))
        end
        build(&blk)
      end

      # Verify that the machine is well defined.
      # @return [void]
      def verify!
        verify_start_state!
        verify_transition_targets!
        verify_exiting_transitions!
      end

      # Define the start state for this state machine.
      # @param name [Symbol]
      # @return [void]
      def start_state(name)
        @start_state = name
      end

      # Generate a new state.
      #
      # @example
      #   machine.state(:create_lockfile,
      #     action: -> { Puppet::Util::Lockfile.new("/var/lock/puppet.lock").lock },
      #     event: ->(has_lock) { has_lock ? :got_lock : :already_locked },
      #     transitions: {
      #       got_lock: :run_agent,
      #       already_locked: :cancel_run,
      #     })
      #
      # @return [Puppet::StateMachine::State] The generated machine state
      def state(state_name, opts = {})
        unhandled = opts.keys - [:action, :event, :type, :transitions]
        if !unhandled.empty?
          raise ArgumentError, "Cannot define state #{state_name.inspect}: unhandled attributes #{unhandled.inspect}"
        end
        if @states[state_name]
          raise ArgumentError, "State #{state_name.inspect} already defined for state machine #{@machine_name.inspect}"
        end
        if [:error, :final].include?(opts[:type])
          opts[:action] ||= lambda { }
          if opts[:event]
            raise ArgumentError, "State #{state_name.inspect} with terminating type #{opts[:type]} cannot be defined with an event proc"
          end
        else
          if !opts[:action]
            raise ArgumentError, "State #{state_name.inspect} with must be defined with an action proc"
          end
          if !opts[:event]
            raise ArgumentError, "State #{state_name.inspect} with must be defined with an event proc"
          end
        end
        trans = {}
        if opts[:transitions]
          opts[:transitions].each do |event, target|
            trans[event] = target
          end
        end
        @states[state_name] = State.new(state_name, opts[:action], opts[:event], opts[:type], trans)
      end

      # Add a transition between states.
      #
      # @note The source state must be defined before defining transitions for that state.
      #
      # @example
      #   machine.transition(
      #     source: :create_lockfile,
      #     target: :run_agent,
      #     on: :got_lock)
      #
      # @return [Hash<Event, Target>] The defined transitions for the named source state
      def transition(opts)
        source = opts[:source]
        target = opts[:target]
        event = opts[:on]
        source_state = @states[opts[:source]]

        if source.nil?
          raise ArgumentError, "Unable to add transition: source state not defined"
        end

        if target.nil?
          raise ArgumentError, "Unable to add transition: target state not defined"
        end

        if event.nil?
          raise ArgumentError, "Unable to add transition: transition event not defined"
        end

        if source_state.nil?
          raise ArgumentError, "Unable to add transition '#{opts[:source]}' to '#{opts[:target]}': source state '#{opts[:source]}' is not defined"
        end

        source_state.transitions[event] = target
        source_state.transitions
      end

      # Mark a state as final.
      #
      # Composing state machines strips the final status from states so that the machines can be
      # composed; states that should be final in the composed machine must be individually marked
      # as final with this method.
      def final(*state_names)
        state_names.each do |state_name|
          s = @states[state_name]
          if s.nil?
            raise ArgumentError, "Cannot mark state '#{state_name}' as final: state not defined"
          else
            s.type = :final
          end
        end
      end

      private

      def verify_start_state!
        if @start_state.nil?
          raise ArgumentError, "Unable to build state machine '#{@machine_name}': start state not named"
        elsif @states[@start_state].nil?
          raise ArgumentError, "Unable to build state machine '#{@machine_name}': start state '#{@start_state}' not defined"
        end
      end

      def verify_transition_targets!
        @states.values.each do |state|
          state.transitions.each_pair do |event, target|
            if @states[target].nil?
              raise ArgumentError, "Unable to build state machine '#{@machine_name}': invalid transition from from state '#{state.name}' to missing state '#{target}'"
            end
          end
        end
      end

      def verify_exiting_transitions!
        @states.values.each do |state|
          if !state.terminal? && state.transitions.empty?
            raise ArgumentError, "Unable to build state machine '#{@machine_name}': state '#{state.name}' is not a final or error state but has no exiting transitions"
          end
        end
      end
    end
  end
end
