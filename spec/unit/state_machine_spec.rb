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
end
