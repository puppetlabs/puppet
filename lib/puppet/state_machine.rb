module Puppet
  # Define state machines for modeling complex operations.
  #
  # A given state machine is immutable once built; invoking the state machine generates a context
  # for that invocation that leaves the state machine and associated states unmodified.
  class StateMachine
    require 'puppet/state_machine/state'
    require 'puppet/state_machine/machine_builder'
    require 'puppet/state_machine/machine_runner'

    # Define, verify, and build a new state machine
    #
    # @example
    #   Puppet::StateMachine.build("Example Puppet runner") do |m|
    #     m.start_state(:start)
    #
    #     m.state(:start,
    #       action: -> { Puppet.notice("Starting Puppet agent") },
    #       event: ->(result) { :create_lockfile },
    #       transitions: {create_lockfile: :create_lockfile})
    #
    #     m.state(:create_lockfile,
    #       action: -> { Puppet::Util::Lockfile.new("/var/lock/puppet.lock").lock },
    #       event: ->(has_lock) { has_lock ? :got_lock : :already_locked },
    #       transitions: {
    #         got_lock: :run_agent,
    #         already_locked: :cancel_run,
    #       })
    #
    #     m.state(:cancel_run,
    #       type: :error,
    #       action: -> { Puppet.error("Cancelling run.") }
    #
    #     m.state(:run_agent,
    #       action: -> { Puppet::Agent.run },
    #       event: ->(exit_code) { exit_code == 0 ? :success : :failure },
    #       transitions: {
    #         success: :shutdown_success,
    #         failure: :shutdown_failure
    #       })
    #
    #     m.state(:shutdown_success,
    #       type: :final,
    #       action: -> do
    #         Puppet::Util::Lockfile.new("/var/lock/puppet.lock").unlock
    #         Puppet.notice("Puppet run complete")
    #       end
    #
    #     m.state(:shutdown_failure,
    #       type: :error,
    #       action: -> do
    #         Puppet::Util::Lockfile.new("/var/lock/puppet.lock").unlock
    #         Puppet.error("Puppet run failed")
    #       end
    #   end
    #
    # @see [Puppet::StateMachine::MachineBuilder]
    # @return [Puppet::StateMachine]
    def self.build(name, &block)
      Puppet::StateMachine::MachineBuilder.new(name).build(&block)
    end

    # Compose multiple state machines into a single state machine.
    #
    # The compose method takes multiple state machines, adds a namespace to all of the state and
    # transition names, and then collects those states into a new machine.
    #
    # ### Namespacing
    #
    # When a state is namespaced, it adds the given namespace to the state name and transitions.
    # Given a machine like the following:
    #
    #     Puppet::StateMachine.build("trivial") do |m|
    #       m.start_state(:start)
    #       m.state(:start,
    #         action: { Puppet.notice("trivial") },
    #         final: true
    #       end
    #     end
    #
    # When the machine is composed with the namespace `:ns1`, the `:start`: state name becomes
    # `[:ns1, :start]`. If the machine is namespaced again with `:ns`, the state name becomes
    # `[:ns2, :ns1, :start]`.
    #
    # ### Final states
    #
    # States that were marked as final are converted to intermediate states so that transitions
    # can be added between states. Converted states receive a new event
    #
    #
    # @example Creating two state machines and composing them in a chain
    #   machine1 = Puppet::StateMachine.build("Machine 1") do |m|
    #     m.state(:m1_start,
    #       action: -> { Puppet.notice("Starting machine 1") },
    #       event: ->(result) { :started },
    #       transitions: {started: :m1_final})
    #
    #     m.state(:m1_final,
    #       action: -> { Puppet.notice("Finishing machine 1") },
    #       type: :final)
    #   end
    #
    #   machine2 = Puppet::StateMachine.build("Machine 2") do |m|
    #     m.state(:m2_start,
    #       action: -> { Puppet.notice("Starting machine 2") },
    #       event: ->(result) { :started },
    #       transitions: {started: :m2_final})
    #
    #     m.state(:m2_final,
    #       action: -> { Puppet.notice("Finishing machine 2") },
    #       type: :final)
    #   end
    #
    #   composed = Puppet::StateMachine.compose("Composed machine",
    #   {
    #     m1: machine1,
    #     m2: machine2
    #   }) do |m|
    #     m.start_state(:composed_start)
    #
    #     # Define new start state that transitions to m1
    #     m.state(:composed_start,
    #       action: -> { Puppet.notice("Starting composed machine") },
    #       event: ->(result) { :started },
    #       transitions: {started: [:m1, :m1_start]})
    #
    #     # Define a new final state that m2 will transition to when finished
    #     m.state(:composed_final,
    #       type: :final,
    #       action: -> { Puppet.notice("Finishing composed machine") })
    #
    #     # Transition from m1 when finished to m2 start
    #     m.transition(
    #       source: [:m1, :m1_final],
    #       target: [:m2, :m2_start],
    #       on: Puppet::StateMachine::FINAL_EVENT)
    #
    #     # Transition from m2 final state to composed machine final state
    #     m.transition(
    #       source: [:m2, :m2_final],
    #       target: :composed_final,
    #       on: Puppet::StateMachine::FINAL_EVENT)
    #
    #   end
    #
    def self.compose(name, machines, &block)
      Puppet::StateMachine::MachineBuilder.new(name).compose(machines, &block)
    end

    # @!attribute [r] name
    #   @return [String] The description of this state machine
    attr_reader :name

    # @!attribute [r] states
    #   @api private
    #   @return [Hash<Symbol, Puppet::StateMachine::State>]
    attr_reader :states

    # @param name [String] The description of this state machine.
    # @param states [Hash<Symbol, Puppet::StateMachine::State>]
    # @param start_state [Symbol] The name of the initial state used when executing this machine.
    def initialize(name, states, start_state)
      @name = name
      @states = states
      @start_state = start_state
    end

    # @return [Puppet::StateMachine::State]
    def start_state
      @states[@start_state]
    end

    def state(state_name)
      @states[state_name]
    end

    # Generate a set of state machine states with the given namespace added to the state name
    # and transitions.
    #
    # @param ns [Symbol]
    # @return [Hash<(Symbol, Array<Symbol>), Puppet::StateMachine::State>]
    def namespace_states(ns)
      @states.values.reduce({}) do |hash, state|
        namespaced = state.namespace(ns)
        hash[namespaced.name] = namespaced
        hash
      end
    end

    # Generate a new state machine context and run this machine.
    def call
      Puppet::StateMachine::MachineRunner.new(self).call
    end

    # The event emitted on final states that have been namespaced and added to a composed machine.
    FINAL_EVENT = :'*final*'
  end
end
