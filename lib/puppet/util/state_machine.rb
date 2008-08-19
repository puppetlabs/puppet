require 'puppet/util'

# A simple class for defining simple state machines.  You define
# the state transitions, which translate to the states a given property
# can be in and the methods used to transition between those states.
#
# == Example
#
# newproperty(:ensure) do
#
#   :absent => :present (:create)
#
#   statemachine.new(:create => {:absent => :present}, :destroy => {:present => :absent})
#
#       mach.transition(:absent => :present).with :create
#       mach.transition(:present => :absent).with :destroy
#
#       mach.transition :create => {:absent => :present}, :destroy => {:present => :absent}

require 'puppet/simple_graph'
require 'puppet/relationship'

class Puppet::Util::StateMachine
    class Transition < Puppet::Relationship
    end

    def initialize(&block)
        @graph = Puppet::SimpleGraph.new
        @docs = {}

        instance_eval(&block) if block
    end

    # Define a state, with docs.
    def state(name, docs)
        @docs[name] = docs
        @graph.add_vertex(name)
    end

    # Check whether a state is defined.
    def state?(name)
        @graph.vertex?(name)
    end

    def transition(from, to)
        raise ArgumentError, "Unknown starting state %s" % from unless state?(from)
        raise ArgumentError, "Unknown ending state %s" % to unless state?(to)
        raise ArgumentError, "Transition %s => %s already exists" % [from, to] if @graph.edge?(from, to)
        transition = Transition.new(from, to)
        @graph.add_edge(transition)
    end
end
