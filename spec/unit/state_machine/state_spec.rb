require 'spec_helper'
require 'puppet/state_machine/state'

RSpec.context Puppet::StateMachine::State do
  context "state types" do
    it "can be an error state" do
      state = described_class.new(:test, nil, nil, :error)
      expect(state).to be_error
    end

    it "can be a final state" do
      state = described_class.new(:test, nil, nil, :final)
      expect(state).to be_final
    end
  end

  context "namespacing a state" do
    context "with a special state type" do
      context "final" do
        let(:original) { described_class.new(:test, nil, nil, :final) }

        subject { original.namespace(:ns) }

        it "drops the state type" do
          expect(subject).to_not be_final
        end

        it "overwrites the event block" do
          expect(subject.event(nil)).to eq Puppet::StateMachine::FINAL_EVENT
        end
      end

      context "error" do
        let(:original) { described_class.new(:test, nil, ->(_) { :error_event }, :error) }

        subject { original.namespace(:ns) }

        it "keeps the state type" do
          expect(subject).to be_error
        end

        it "doesn't overwrite the event block" do
          expect(subject.event(nil)).to eq :error_event
        end
      end
    end

    context "that is not yet namespaced" do
      subject do
        described_class.new(:test, -> {}, ->(_) {}, {},
                            {
                              left: :left_state,
                              right: :right_state
                            })
      end

      let!(:namespaced) { subject.namespace(:ns) }

      it "adds a namespace to the state name" do
        expect(namespaced.name).to eq([:ns, :test])
      end

      it "generates a new state with namespaced transitions" do
        expect(namespaced.transition_for(:left)).to eq([:ns, :left_state])
      end

      it "doesn't modify the original state" do
        expect(subject.transition_for(:left)).to eq(:left_state)
      end
    end

    context "that is already namespaced" do
      subject do
        described_class.new(:test, -> {}, ->(_) {}, {},
                            {
                              left: :left_state,
                              right: :right_state
        }).namespace(:ns1)
      end

      let!(:namespaced) { subject.namespace(:ns2) }

      it "adds a namespace to the state name" do
        expect(namespaced.name).to eq([:ns2, :ns1, :test])
      end

      it "prepends the new namespace in front of the existing namespaced transitions" do
        expect(namespaced.transition_for(:left)).to eq([:ns2, :ns1, :left_state])
      end

      it "doesn't modify the original state" do
        expect(subject.transition_for(:left)).to eq([:ns1, :left_state])
      end
    end
  end
end
