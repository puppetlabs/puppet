require 'spec_helper'
require 'puppet/state_machine'

context Puppet::StateMachine do
  context "adding a namespace to the states" do
    context "that have not been namespaced" do
      subject do
        Puppet::StateMachine.build("test") do |m|
          m.start_state(:x)
          m.state(:x,
                  action: -> {},
                  event: ->(_) { :e1 },
                  transitions: {e1: :y})

          m.state(:y,
                  action: -> {},
                  event: ->(_) { :e2 },
                  transitions: {e2: :x})
        end
      end

      it "generates properly namespaced states" do
        states = subject.namespace_states(:ns)

        ns_x = states[[:ns, :x]]
        ns_y = states[[:ns, :y]]

        expect(ns_x.name).to eq([:ns, :x])
        expect(ns_x.transition_for(:e1)).to eq([:ns, :y])

        expect(ns_y.name).to eq([:ns, :y])
        expect(ns_y.transition_for(:e2)).to eq([:ns, :x])
      end
    end
  end

  context "invoking the state machine" do
    context "halting" do
      it "halts the state machine on error states" do
        machine = Puppet::StateMachine.build("test") do |m|
          m.start_state(:x)
          m.state(:x,
                  action: -> {},
                  event: ->(_) { :e },
                  transitions: {e: :y})

          m.state(:y, type: :error)
        end

        expect(machine.call).to eq :errored
      end

      it "halts the state machine on final states" do
        machine = Puppet::StateMachine.build("test") do |m|
          m.start_state(:x)
          m.state(:x,
                  action: -> {},
                  event: ->(_) { :e },
                  transitions: {e: :y})

          m.state(:y, type: :final)
        end

        expect(machine.call).to eq :complete
      end
    end
    context "handling errors" do
      it "raises an error when a state returns a nil event" do
        machine = Puppet::StateMachine.build("test") do |m|
          m.start_state(:x)
          m.state(:x,
                  action: -> {},
                  event: ->(_) { },
                  transitions: {e1: :y})

          m.state(:y, type: :final)
        end

        expect {
          machine.call
        }.to raise_error(Puppet::DevError, /Cannot determine transition for state .*x.*: no event was returned/)
      end

      it "raises an error when an event is returned that doesn't have a matching transition" do
        machine = Puppet::StateMachine.build("test") do |m|
          m.start_state(:x)
          m.state(:x,
                  action: -> {},
                  event: ->(_) { :e2 },
                  transitions: {e1: :y})

            m.state(:y, type: :final)
        end

        expect {
          machine.call
        }.to raise_error(Puppet::DevError, /State .*x.* does not define a transition for event .*e/)
      end
    end
  end
end
