require 'puppet/state_machine'

module Puppet
  class StateMachine
    # Define the actions, events, and transitions for an invididual state in a state machine.
    #
    # ## Callbacks
    #
    # A state has two callbacks: the action callback, and the event callback.
    #
    # The action callback performs the actual work associated with a given state. It takes no arguments
    # and returns the result of the action. In some cases there may not be any work for a given state,
    # in which case an empty callback can be used.
    #
    # The event callback determines which transition to follow after this state. It takes the result of
    # the action block and returns a symbol naming the event that occurred.
    #
    # ## Events and transitions
    #
    # Evaluating a state generates an event, indicating the type of work that the state performed or the
    # outcome of some query operation. Each event is associated with a transition naming the next state
    # to enter.
    #
    # Transitions define a directed edge between states in a state machine. A transition is defined as the
    # source state, the target state, and an event that causes that transition to be taken.
    #
    # ## Namespacing
    #
    # When state machines are composed individual state names need to remain unique. States can be namespaced
    # which converts state names and transition names from a single symbol to a list of symbols.
    #
    class State

      # @!attribute [r] name
      #   @return [Symbol, Array<Symbol>] The name of this state. This name is used when determining and validating state machine transitions.
      attr_reader :name

      # @!attribute [r] transitions
      #   @api private
      #   @return [Hash<Symbol, Symbol>] A map of events and their corresponding transitions.
      attr_reader :transitions

      # @!attribute [r] type
      #   @api private
      #   @return [nil, :error, :final] The state type, or nil if the state is intermediate
      attr_accessor :type

      # @param name [Symbol, Array<Symbol>] A symbol or list of symbols identifying this state.
      # @param action_cb [#call()] The action callback to invoke when entering this state. The return value of this state is passed to the event callback.
      # @param event_cb [#call(Object)] The event callback to determine the next transition to take.
      # @param options [Hash] A map of options indicating what kind of state this is.
      # @param transitions [Hash<Symbol, <Symbol>>] A map of events and their corresponding transitions.
      def initialize(name, action_cb, event_cb, type = nil, transitions = {})
        @name = name
        @action_cb = action_cb
        @event_cb = event_cb
        @type = type

        @transitions = transitions
      end

      def call
        event(action)
      end

      def action
        @action_cb.call
      end

      def event(result)
        @event_cb.call(result)
      end

      def transition_for(event)
        @transitions[event]
      end

      def error?
        @type == :error
      end

      def final?
        @type == :final
      end

      def terminal?
        error? || final?
      end

      # Generate a new state with namespaced transitions.
      #
      # In order to compose multiple state machines into a single machine, the states of an
      # individual machine need to be namespaced to prevent name collisions across different
      # machines and identify which states originated from which of the individual machines.
      #
      # @param ns [Symbol]
      # @return [Puppet::StateMachine::State]
      def namespace(ns)
        new_name = namespace_value(ns, @name)
        new_transitions = Hash[@transitions.map do |(event, target)|
          [event, namespace_value(ns, target)]
        end]

        new_type = @type
        if new_type == :final
          new_event_cb = ->(_) { Puppet::StateMachine::FINAL_EVENT }
          new_type = nil
        else
          new_event_cb = @event_cb
        end
        Puppet::StateMachine::State.new(new_name, @action_cb, new_event_cb, new_type, new_transitions)
      end

      private

      def namespace_value(ns, value)
        Array(value).dup.unshift(ns)
      end
    end
  end
end
