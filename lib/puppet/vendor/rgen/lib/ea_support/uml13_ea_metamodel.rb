require 'rgen/metamodel_builder'

module UML13EA
   extend RGen::MetamodelBuilder::ModuleExtension
   include RGen::MetamodelBuilder::DataTypes

   OperationDirectionKind = Enum.new(:name => 'OperationDirectionKind', :literals =>[ ])
   MessageDirectionKind = Enum.new(:name => 'MessageDirectionKind', :literals =>[ ])
   ChangeableKind = Enum.new(:name => 'ChangeableKind', :literals =>[ :changeable, :none, :addOnly ])
   PseudostateKind = Enum.new(:name => 'PseudostateKind', :literals =>[ :initial, :deepHistory, :shallowHistory, :join, :fork, :branch, :junction, :final ])
   ParameterDirectionKind = Enum.new(:name => 'ParameterDirectionKind', :literals =>[ :in, :inout, :out, :return ])
   ScopeKind = Enum.new(:name => 'ScopeKind', :literals =>[ :instance, :classifier ])
   OrderingKind = Enum.new(:name => 'OrderingKind', :literals =>[ :unordered, :ordered, :sorted ])
   CallConcurrencyKind = Enum.new(:name => 'CallConcurrencyKind', :literals =>[ :sequential, :guarded, :concurrent ])
   AggregationKind = Enum.new(:name => 'AggregationKind', :literals =>[ :none, :aggregate, :composite, :shared ])
   VisibilityKind = Enum.new(:name => 'VisibilityKind', :literals =>[ :public, :protected, :private ])
end

class UML13EA::Expression < RGen::MetamodelBuilder::MMBase
   has_attr 'language', String 
   has_attr 'body', String 
end

class UML13EA::ActionExpression < UML13EA::Expression
end

class UML13EA::Element < RGen::MetamodelBuilder::MMBase
end

class UML13EA::ModelElement < UML13EA::Element
   has_attr 'name', String 
   has_attr 'visibility', UML13EA::VisibilityKind, :defaultValueLiteral => "public" 
   has_attr 'isSpecification', Boolean 
end

class UML13EA::Namespace < UML13EA::ModelElement
end

class UML13EA::GeneralizableElement < UML13EA::ModelElement
   has_attr 'isRoot', Boolean 
   has_attr 'isLeaf', Boolean 
   has_attr 'isAbstract', Boolean 
end

class UML13EA::Classifier < RGen::MetamodelBuilder::MMMultiple(UML13EA::GeneralizableElement, UML13EA::Namespace)
end

class UML13EA::ClassifierRole < UML13EA::Classifier
end

class UML13EA::PresentationElement < UML13EA::Element
end

class UML13EA::DiagramElement < UML13EA::PresentationElement
   has_attr 'geometry', String 
   has_attr 'style', String 
end

class UML13EA::Feature < UML13EA::ModelElement
   has_attr 'ownerScope', UML13EA::ScopeKind, :defaultValueLiteral => "instance" 
end

class UML13EA::BehavioralFeature < UML13EA::Feature
   has_attr 'isQuery', Boolean 
end

class UML13EA::Method < UML13EA::BehavioralFeature
end

class UML13EA::Actor < UML13EA::Classifier
end

class UML13EA::DataType < UML13EA::Classifier
end

class UML13EA::Primitive < UML13EA::DataType
end

class UML13EA::Action < UML13EA::ModelElement
   has_attr 'isAsynchronous', Boolean 
end

class UML13EA::SendAction < UML13EA::Action
end

class UML13EA::Interface < UML13EA::Classifier
end

class UML13EA::Event < UML13EA::ModelElement
end

class UML13EA::ChangeEvent < UML13EA::Event
end

class UML13EA::Partition < UML13EA::ModelElement
end

class UML13EA::Comment < UML13EA::ModelElement
   has_attr 'body', String 
end

class UML13EA::ProgrammingLanguageType < UML13EA::DataType
end

class UML13EA::StateMachine < UML13EA::ModelElement
end

class UML13EA::Call < RGen::MetamodelBuilder::MMBase
end

class UML13EA::Operation < UML13EA::BehavioralFeature
   has_attr 'concurrency', UML13EA::CallConcurrencyKind, :defaultValueLiteral => "sequential" 
   has_attr 'isRoot', Boolean 
   has_attr 'isLeaf', Boolean 
   has_attr 'isAbstract', Boolean 
end

class UML13EA::XmiIdProvider < RGen::MetamodelBuilder::MMBase
end

class UML13EA::StateVertex < RGen::MetamodelBuilder::MMMultiple(UML13EA::ModelElement, UML13EA::XmiIdProvider)
end

class UML13EA::SynchState < UML13EA::StateVertex
   has_attr 'bound', Integer 
end

class UML13EA::ClassifierInState < UML13EA::Classifier
end

class UML13EA::Link < UML13EA::ModelElement
end

class UML13EA::ProcedureExpression < UML13EA::Expression
end

class UML13EA::CallEvent < UML13EA::Event
end

class UML13EA::AssignmentAction < UML13EA::Action
end

class UML13EA::Relationship < UML13EA::ModelElement
end

class UML13EA::Association < RGen::MetamodelBuilder::MMMultiple(UML13EA::GeneralizableElement, UML13EA::Relationship, UML13EA::XmiIdProvider)
end

class UML13EA::AssociationRole < UML13EA::Association
end

class UML13EA::Diagram < UML13EA::PresentationElement
   has_attr 'name', String 
   has_attr 'toolName', String 
   has_attr 'diagramType', String 
   has_attr 'style', String 
end

class UML13EA::MultiplicityRange < RGen::MetamodelBuilder::MMBase
   has_attr 'lower', String 
   has_attr 'upper', String 
end

class UML13EA::ActionSequence < UML13EA::Action
end

class UML13EA::Constraint < UML13EA::ModelElement
end

class UML13EA::Instance < UML13EA::ModelElement
end

class UML13EA::UseCaseInstance < UML13EA::Instance
end

class UML13EA::State < UML13EA::StateVertex
end

class UML13EA::CompositeState < UML13EA::State
   has_attr 'isConcurrent', Boolean 
end

class UML13EA::SubmachineState < UML13EA::CompositeState
end

class UML13EA::SubactivityState < UML13EA::SubmachineState
   has_attr 'isDynamic', Boolean 
end

class UML13EA::StructuralFeature < UML13EA::Feature
   has_attr 'changeable', UML13EA::ChangeableKind, :defaultValueLiteral => "changeable" 
   has_attr 'targetScope', UML13EA::ScopeKind, :defaultValueLiteral => "instance" 
end

class UML13EA::Attribute < UML13EA::StructuralFeature
end

class UML13EA::Flow < UML13EA::Relationship
end

class UML13EA::Class < RGen::MetamodelBuilder::MMMultiple(UML13EA::Classifier, UML13EA::XmiIdProvider)
   has_attr 'isActive', Boolean 
end

class UML13EA::Guard < UML13EA::ModelElement
end

class UML13EA::CreateAction < UML13EA::Action
end

class UML13EA::IterationExpression < UML13EA::Expression
end

class UML13EA::ReturnAction < UML13EA::Action
end

class UML13EA::Parameter < UML13EA::ModelElement
   has_attr 'kind', UML13EA::ParameterDirectionKind, :defaultValueLiteral => "inout" 
end

class UML13EA::Dependency < UML13EA::Relationship
end

class UML13EA::Binding < UML13EA::Dependency
end

class UML13EA::Package < RGen::MetamodelBuilder::MMMultiple(UML13EA::Namespace, UML13EA::GeneralizableElement, UML13EA::XmiIdProvider)
end

class UML13EA::ObjectSetExpression < UML13EA::Expression
end

class UML13EA::StubState < UML13EA::StateVertex
   has_attr 'referenceState', String 
end

class UML13EA::Stereotype < UML13EA::GeneralizableElement
   has_attr 'icon', String 
   has_attr 'baseClass', String 
end

class UML13EA::Object < UML13EA::Instance
end

class UML13EA::LinkObject < RGen::MetamodelBuilder::MMMultiple(UML13EA::Link, UML13EA::Object)
end

class UML13EA::ComponentInstance < UML13EA::Instance
end

class UML13EA::Usage < UML13EA::Dependency
end

class UML13EA::SignalEvent < UML13EA::Event
end

class UML13EA::Structure < UML13EA::DataType
end

class UML13EA::AssociationEnd < RGen::MetamodelBuilder::MMMultiple(UML13EA::ModelElement, UML13EA::XmiIdProvider)
   has_attr 'isNavigable', Boolean, :defaultValueLiteral => "false" 
   has_attr 'isOrdered', Boolean, :defaultValueLiteral => "false" 
   has_attr 'aggregation', UML13EA::AggregationKind, :defaultValueLiteral => "none" 
   has_attr 'targetScope', UML13EA::ScopeKind, :defaultValueLiteral => "instance" 
   has_attr 'changeable', UML13EA::ChangeableKind, :defaultValueLiteral => "changeable" 
   has_attr 'multiplicity', String 
end

class UML13EA::AssociationEndRole < UML13EA::AssociationEnd
end

class UML13EA::Signal < UML13EA::Classifier
end

class UML13EA::Exception < UML13EA::Signal
end

class UML13EA::Extend < UML13EA::Relationship
end

class UML13EA::Argument < UML13EA::ModelElement
end

class UML13EA::TemplateParameter < RGen::MetamodelBuilder::MMBase
end

class UML13EA::PseudoState < UML13EA::StateVertex
   has_attr 'kind', UML13EA::PseudostateKind, :defaultValueLiteral => "initial" 
end

class UML13EA::SimpleState < UML13EA::State
end

class UML13EA::ActionState < UML13EA::SimpleState
   has_attr 'isDynamic', Boolean 
end

class UML13EA::TypeExpression < UML13EA::Expression
end

class UML13EA::DestroyAction < UML13EA::Action
end

class UML13EA::TerminateAction < UML13EA::Action
end

class UML13EA::Generalization < RGen::MetamodelBuilder::MMMultiple(UML13EA::Relationship, UML13EA::XmiIdProvider)
   has_attr 'discriminator', String 
end

class UML13EA::FinalState < UML13EA::State
end

class UML13EA::Subsystem < RGen::MetamodelBuilder::MMMultiple(UML13EA::Package, UML13EA::Classifier)
   has_attr 'isInstantiable', Boolean 
end

class UML13EA::TimeExpression < UML13EA::Expression
end

class UML13EA::TaggedValue < UML13EA::Element
   has_attr 'tag', String 
   has_attr 'value', String 
end

class UML13EA::DataValue < UML13EA::Instance
end

class UML13EA::Transition < UML13EA::ModelElement
end

class UML13EA::NodeInstance < UML13EA::Instance
end

class UML13EA::Component < UML13EA::Classifier
end

class UML13EA::Message < UML13EA::ModelElement
end

class UML13EA::Enumeration < UML13EA::DataType
end

class UML13EA::Reception < UML13EA::BehavioralFeature
   has_attr 'isPolymorphic', Boolean 
   has_attr 'specification', String 
end

class UML13EA::Include < UML13EA::Relationship
end

class UML13EA::CallState < UML13EA::ActionState
end

class UML13EA::ElementResidence < RGen::MetamodelBuilder::MMBase
   has_attr 'visibility', UML13EA::VisibilityKind, :defaultValueLiteral => "public" 
end

class UML13EA::UninterpretedAction < UML13EA::Action
end

class UML13EA::ArgListsExpression < UML13EA::Expression
end

class UML13EA::Stimulus < UML13EA::ModelElement
end

class UML13EA::AssociationClass < RGen::MetamodelBuilder::MMMultiple(UML13EA::Class, UML13EA::Association)
end

class UML13EA::Node < UML13EA::Classifier
end

class UML13EA::ElementImport < RGen::MetamodelBuilder::MMBase
   has_attr 'visibility', UML13EA::VisibilityKind, :defaultValueLiteral => "public" 
   has_attr 'alias', String 
end

class UML13EA::BooleanExpression < UML13EA::Expression
end

class UML13EA::Collaboration < RGen::MetamodelBuilder::MMMultiple(UML13EA::GeneralizableElement, UML13EA::Namespace)
end

class UML13EA::CallAction < UML13EA::Action
end

class UML13EA::UseCase < UML13EA::Classifier
end

class UML13EA::ActivityModel < UML13EA::StateMachine
end

class UML13EA::Permission < UML13EA::Dependency
end

class UML13EA::Interaction < UML13EA::ModelElement
end

class UML13EA::EnumerationLiteral < RGen::MetamodelBuilder::MMBase
   has_attr 'name', String 
end

class UML13EA::Model < UML13EA::Package
end

class UML13EA::LinkEnd < UML13EA::ModelElement
end

class UML13EA::ExtensionPoint < UML13EA::ModelElement
   has_attr 'location', String 
end

class UML13EA::Multiplicity < RGen::MetamodelBuilder::MMBase
end

class UML13EA::ObjectFlowState < UML13EA::SimpleState
   has_attr 'isSynch', Boolean 
end

class UML13EA::AttributeLink < UML13EA::ModelElement
end

class UML13EA::MappingExpression < UML13EA::Expression
end

class UML13EA::TimeEvent < UML13EA::Event
end

class UML13EA::Abstraction < UML13EA::Dependency
end

class UML13EA::ActionInstance < RGen::MetamodelBuilder::MMBase
end


UML13EA::ClassifierRole.contains_one_uni 'multiplicity', UML13EA::Multiplicity 
UML13EA::ClassifierRole.has_many 'availableContents', UML13EA::ModelElement 
UML13EA::ClassifierRole.has_many 'availableFeature', UML13EA::Feature 
UML13EA::ClassifierRole.has_one 'base', UML13EA::Classifier, :lowerBound => 1 
UML13EA::Diagram.contains_many 'element', UML13EA::DiagramElement, 'diagram' 
UML13EA::Method.many_to_one 'specification', UML13EA::Operation, 'method' 
UML13EA::Method.contains_one_uni 'body', UML13EA::ProcedureExpression 
UML13EA::SendAction.has_one 'signal', UML13EA::Signal, :lowerBound => 1 
UML13EA::ChangeEvent.contains_one_uni 'changeExpression', UML13EA::BooleanExpression 
UML13EA::Partition.has_many 'contents', UML13EA::ModelElement 
UML13EA::Comment.many_to_many 'annotatedElement', UML13EA::ModelElement, 'comment' 
UML13EA::ProgrammingLanguageType.contains_one_uni 'type', UML13EA::TypeExpression 
UML13EA::Action.contains_one_uni 'recurrence', UML13EA::IterationExpression 
UML13EA::Action.contains_one_uni 'target', UML13EA::ObjectSetExpression 
UML13EA::Action.contains_one_uni 'script', UML13EA::ActionExpression 
UML13EA::Action.contains_many_uni 'actualArgument', UML13EA::Argument 
UML13EA::StateMachine.many_to_one 'context', UML13EA::ModelElement, 'behavior' 
UML13EA::StateMachine.contains_many_uni 'transitions', UML13EA::Transition 
UML13EA::StateMachine.contains_one_uni 'top', UML13EA::State, :lowerBound => 1 
UML13EA::Operation.one_to_many 'occurrence', UML13EA::CallEvent, 'operation' 
UML13EA::ClassifierInState.has_one 'type', UML13EA::Classifier, :lowerBound => 1 
UML13EA::ClassifierInState.has_many 'inState', UML13EA::State 
UML13EA::Link.contains_many_uni 'connection', UML13EA::LinkEnd, :lowerBound => 2 
UML13EA::Link.has_one 'association', UML13EA::Association, :lowerBound => 1 
UML13EA::PresentationElement.many_to_many 'subject', UML13EA::ModelElement, 'presentation' 
UML13EA::AssociationRole.contains_one_uni 'multiplicity', UML13EA::Multiplicity 
UML13EA::AssociationRole.has_one 'base', UML13EA::Association 
UML13EA::Diagram.has_one 'owner', UML13EA::ModelElement, :lowerBound => 1 
UML13EA::ActionSequence.contains_many_uni 'action', UML13EA::Action 
UML13EA::Constraint.contains_one_uni 'body', UML13EA::BooleanExpression 
UML13EA::Constraint.many_to_many 'constrainedElement', UML13EA::ModelElement, 'constraint', :lowerBound => 1 
UML13EA::SubactivityState.contains_one_uni 'dynamicArguments', UML13EA::ArgListsExpression 
UML13EA::AssociationEnd.contains_many 'qualifier', UML13EA::Attribute, 'associationEnd' 
UML13EA::Attribute.contains_one_uni 'initialValue', UML13EA::Expression 
UML13EA::Flow.many_to_many 'source', UML13EA::ModelElement, 'sourceFlow' 
UML13EA::Flow.many_to_many 'target', UML13EA::ModelElement, 'targetFlow' 
UML13EA::Guard.contains_one_uni 'expression', UML13EA::BooleanExpression 
UML13EA::CreateAction.has_one 'instantiation', UML13EA::Classifier, :lowerBound => 1 
UML13EA::Namespace.contains_many 'ownedElement', UML13EA::ModelElement, 'namespace' 
UML13EA::Parameter.contains_one_uni 'defaultValue', UML13EA::Expression 
UML13EA::Parameter.many_to_many 'state', UML13EA::ObjectFlowState, 'parameter' 
UML13EA::Parameter.has_one 'type', UML13EA::Classifier, :lowerBound => 1 
UML13EA::Binding.has_many 'argument', UML13EA::ModelElement, :lowerBound => 1 
UML13EA::Event.contains_many_uni 'parameters', UML13EA::Parameter 
UML13EA::Dependency.many_to_many 'supplier', UML13EA::ModelElement, 'supplierDependency', :opposite_lowerBound => 1 
UML13EA::Dependency.many_to_many 'client', UML13EA::ModelElement, 'clientDependency', :opposite_lowerBound => 1 
UML13EA::Package.contains_many 'importedElement', UML13EA::ElementImport, 'package' 
UML13EA::Classifier.contains_many 'feature', UML13EA::Feature, 'owner' 
UML13EA::Stereotype.one_to_many 'extendedElement', UML13EA::ModelElement, 'stereotype' 
UML13EA::Stereotype.has_many 'requiredTag', UML13EA::TaggedValue 
UML13EA::ComponentInstance.has_many 'resident', UML13EA::Instance 
UML13EA::SignalEvent.many_to_one 'signal', UML13EA::Signal, 'occurrence', :lowerBound => 1 
UML13EA::Instance.contains_many_uni 'slot', UML13EA::AttributeLink 
UML13EA::Instance.one_to_many 'linkEnd', UML13EA::LinkEnd, 'instance' 
UML13EA::Instance.has_many 'classifier', UML13EA::Classifier, :lowerBound => 1 
UML13EA::AssociationEndRole.has_many 'availableQualifier', UML13EA::Attribute 
UML13EA::AssociationEndRole.has_one 'base', UML13EA::AssociationEnd 
UML13EA::Extend.many_to_one 'extension', UML13EA::UseCase, 'extend' 
UML13EA::Extend.contains_one_uni 'condition', UML13EA::BooleanExpression 
UML13EA::Extend.has_many 'extensionPoint', UML13EA::ExtensionPoint, :lowerBound => 1 
UML13EA::Extend.has_one 'base', UML13EA::UseCase, :lowerBound => 1 
UML13EA::Argument.contains_one_uni 'value', UML13EA::Expression 
UML13EA::TemplateParameter.has_one 'modelElement', UML13EA::ModelElement 
UML13EA::TemplateParameter.has_one 'defaultElement', UML13EA::ModelElement 
UML13EA::ActionState.contains_one_uni 'dynamicArguments', UML13EA::ArgListsExpression 
UML13EA::GeneralizableElement.one_to_many 'specialization', UML13EA::Generalization, 'supertype' 
UML13EA::GeneralizableElement.one_to_many 'generalization', UML13EA::Generalization, 'subtype' 
UML13EA::StateVertex.one_to_many 'incoming', UML13EA::Transition, 'target', :opposite_lowerBound => 1 
UML13EA::StateVertex.one_to_many 'outgoing', UML13EA::Transition, 'source', :opposite_lowerBound => 1 
UML13EA::CompositeState.contains_many 'substate', UML13EA::StateVertex, 'container', :lowerBound => 1 
UML13EA::ModelElement.contains_many 'taggedValue', UML13EA::TaggedValue, 'modelElement' 
UML13EA::StructuralFeature.contains_one_uni 'multiplicity', UML13EA::Multiplicity 
UML13EA::StructuralFeature.has_one 'type', UML13EA::Classifier, :lowerBound => 1 
UML13EA::Transition.has_one 'trigger', UML13EA::Event 
UML13EA::Transition.contains_one_uni 'effect', UML13EA::Action 
UML13EA::Transition.contains_one_uni 'guard', UML13EA::Guard 
UML13EA::NodeInstance.has_many 'resident', UML13EA::ComponentInstance 
UML13EA::Component.contains_many 'residentElement', UML13EA::ElementResidence, 'implementationLocation' 
UML13EA::Component.many_to_many 'deploymentLocation', UML13EA::Node, 'resident' 
UML13EA::Message.has_one 'action', UML13EA::Action, :lowerBound => 1 
UML13EA::Message.has_one 'communicationConnection', UML13EA::AssociationRole 
UML13EA::Message.has_many 'predecessor', UML13EA::Message 
UML13EA::Message.has_one 'receiver', UML13EA::ClassifierRole, :lowerBound => 1 
UML13EA::Message.has_one 'sender', UML13EA::ClassifierRole, :lowerBound => 1 
UML13EA::Message.has_one 'activator', UML13EA::Message 
UML13EA::Interaction.contains_many 'message', UML13EA::Message, 'interaction', :lowerBound => 1 
UML13EA::ModelElement.one_to_many 'elementResidence', UML13EA::ElementResidence, 'resident' 
UML13EA::ModelElement.contains_many_uni 'templateParameter', UML13EA::TemplateParameter 
UML13EA::ModelElement.one_to_many 'elementImport', UML13EA::ElementImport, 'modelElement' 
UML13EA::Enumeration.contains_many_uni 'literal', UML13EA::EnumerationLiteral, :lowerBound => 1 
UML13EA::Reception.many_to_one 'signal', UML13EA::Signal, 'reception' 
UML13EA::Association.contains_many 'connection', UML13EA::AssociationEnd, 'association', :lowerBound => 2 
UML13EA::Include.many_to_one 'base', UML13EA::UseCase, 'include' 
UML13EA::Include.has_one 'addition', UML13EA::UseCase, :lowerBound => 1 
UML13EA::Classifier.many_to_many 'participant', UML13EA::AssociationEnd, 'specification' 
UML13EA::Classifier.one_to_many 'associationEnd', UML13EA::AssociationEnd, 'type' 
UML13EA::Stimulus.has_one 'dispatchAction', UML13EA::Action, :lowerBound => 1 
UML13EA::Stimulus.has_one 'communicationLink', UML13EA::Link 
UML13EA::Stimulus.has_one 'receiver', UML13EA::Instance, :lowerBound => 1 
UML13EA::Stimulus.has_one 'sender', UML13EA::Instance, :lowerBound => 1 
UML13EA::Stimulus.has_many 'argument', UML13EA::Instance 
UML13EA::State.contains_one_uni 'doActivity', UML13EA::Action 
UML13EA::State.contains_many_uni 'internalTransition', UML13EA::Transition 
UML13EA::State.has_many 'deferrableEvent', UML13EA::Event 
UML13EA::State.contains_one_uni 'exit', UML13EA::Action 
UML13EA::State.contains_one_uni 'entry', UML13EA::Action 
UML13EA::Collaboration.has_one 'representedOperation', UML13EA::Operation 
UML13EA::Collaboration.has_one 'representedClassifier', UML13EA::Classifier 
UML13EA::Collaboration.has_many 'constrainingElement', UML13EA::ModelElement 
UML13EA::Collaboration.contains_many 'interaction', UML13EA::Interaction, 'context' 
UML13EA::CallAction.has_one 'operation', UML13EA::Operation, :lowerBound => 1 
UML13EA::UseCase.has_many 'extensionPoint', UML13EA::ExtensionPoint 
UML13EA::ActivityModel.contains_many_uni 'partition', UML13EA::Partition 
UML13EA::Interaction.contains_many_uni 'link', UML13EA::Link 
UML13EA::LinkEnd.has_one 'associationEnd', UML13EA::AssociationEnd, :lowerBound => 1 
UML13EA::LinkEnd.has_one 'participant', UML13EA::Instance, :lowerBound => 1 
UML13EA::BehavioralFeature.many_to_many 'raisedSignal', UML13EA::Signal, 'context' 
UML13EA::BehavioralFeature.contains_many_uni 'parameter', UML13EA::Parameter 
UML13EA::SubmachineState.has_one 'submachine', UML13EA::StateMachine, :lowerBound => 1 
UML13EA::Multiplicity.contains_many_uni 'range', UML13EA::MultiplicityRange, :lowerBound => 1 
UML13EA::ObjectFlowState.has_one 'type', UML13EA::Classifier, :lowerBound => 1 
UML13EA::ObjectFlowState.has_one 'available', UML13EA::Parameter, :lowerBound => 1 
UML13EA::AttributeLink.has_one 'value', UML13EA::Instance, :lowerBound => 1 
UML13EA::AttributeLink.has_one 'attribute', UML13EA::Attribute, :lowerBound => 1 
UML13EA::TimeEvent.contains_one_uni 'when', UML13EA::TimeExpression 
UML13EA::Abstraction.contains_one_uni 'mapping', UML13EA::MappingExpression 
