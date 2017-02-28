require 'spec_helper'
require 'puppet/state_machine'

context Puppet::StateMachine::MachineRunner do
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
