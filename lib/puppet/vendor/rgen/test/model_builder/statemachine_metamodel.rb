# a test metamodel used by the following tests
module StatemachineMetamodel
  extend RGen::MetamodelBuilder::ModuleExtension
  
  module Condition
    extend RGen::MetamodelBuilder::ModuleExtension
  
    class Condition < RGen::MetamodelBuilder::MMBase
    end
  
    module TimeCondition
      extend RGen::MetamodelBuilder::ModuleExtension
  
      class TimeCondition < Condition
        has_attr 'timeout', Integer
      end
    end
  end
  
  class Statemachine < RGen::MetamodelBuilder::MMBase
    has_attr 'name'
  end
  
  class State < RGen::MetamodelBuilder::MMBase
    has_attr 'name'
    has_attr 'kind', RGen::MetamodelBuilder::DataTypes::Enum.new([:START])
  end
  
  class CompositeState < State
    has_attr 'name'
    contains_many 'state', State, 'compositeState'
  end
  
  class Transition < RGen::MetamodelBuilder::MMBase
    many_to_one 'sourceState', State, 'outgoingTransition'
    many_to_one 'targetState', State, 'incomingTransition'
    has_many 'condition', Condition::Condition
  end
  
  Statemachine.contains_many 'state', State, 'statemachine'
  Statemachine.contains_many 'transition', Transition, 'statemachine'
end
