statemachine "Airconditioner" do
  state "Off", :kind => :START
  compositeState "On" do
    state "Heating" do
      transition :as => :outgoingTransition, :targetState => "Cooling",
        :statemachine => "Airconditioner"
    end
    state "Cooling" do
    end
  end
  transition :sourceState => "On.Cooling", :targetState => "On.Heating" do
    _using Condition::TimeCondition do
      timeCondition :as => :condition, :timeout => 100
    end
    Condition::TimeCondition.timeCondition :as => :condition, :timeout => 10
  end
end
_using Condition do
  statemachine "AirconExtension" do
    s = state "StartState"
    transition :sourceState => s, :targetState => "Airconditioner.Off"
  end
end
