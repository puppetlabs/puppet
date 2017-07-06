require 'rgen/metamodel_builder'

module UML13
   extend RGen::MetamodelBuilder::ModuleExtension
   include RGen::MetamodelBuilder::DataTypes

   AggregationKind = Enum.new(:name => "AggregationKind", :literals =>[ :none, :aggregate, :composite ])
   ChangeableKind = Enum.new(:name => "ChangeableKind", :literals =>[ :changeable, :frozen, :addOnly ])
   OperationDirectionKind = Enum.new(:name => "OperationDirectionKind", :literals =>[ ])
   ParameterDirectionKind = Enum.new(:name => "ParameterDirectionKind", :literals =>[ :in, :inout, :out, :return ])
   MessageDirectionKind = Enum.new(:name => "MessageDirectionKind", :literals =>[ ])
   ScopeKind = Enum.new(:name => "ScopeKind", :literals =>[ :instance, :classifier ])
   VisibilityKind = Enum.new(:name => "VisibilityKind", :literals =>[ :public, :protected, :private ])
   PseudostateKind = Enum.new(:name => "PseudostateKind", :literals =>[ :initial, :deepHistory, :shallowHistory, :join, :fork, :branch, :junction, :final ])
   CallConcurrencyKind = Enum.new(:name => "CallConcurrencyKind", :literals =>[ :sequential, :guarded, :concurrent ])
   OrderingKind = Enum.new(:name => "OrderingKind", :literals =>[ :unordered, :ordered, :sorted ])

   class Element < RGen::MetamodelBuilder::MMBase
   end

   class ModelElement < Element
      has_attr 'name', String
      has_attr 'visibility', UML13::VisibilityKind, :defaultValueLiteral => "public"
      has_attr 'isSpecification', Boolean
   end

   class Namespace < ModelElement
   end

   class GeneralizableElement < ModelElement
      has_attr 'isRoot', Boolean
      has_attr 'isLeaf', Boolean
      has_attr 'isAbstract', Boolean
   end

   class Classifier < RGen::MetamodelBuilder::MMMultiple(GeneralizableElement, Namespace)
   end

   class Class < Classifier
      has_attr 'isActive', Boolean
   end

   class DataType < Classifier
   end

   class Feature < ModelElement
      has_attr 'ownerScope', UML13::ScopeKind, :defaultValueLiteral => "instance"
   end

   class StructuralFeature < Feature
      has_attr 'changeability', UML13::ChangeableKind, :defaultValueLiteral => "changeable"
      has_attr 'targetScope', UML13::ScopeKind, :defaultValueLiteral => "instance"
   end

   class AssociationEnd < ModelElement
      has_attr 'isNavigable', Boolean, :defaultValueLiteral => "false"
      has_attr 'ordering', UML13::OrderingKind, :defaultValueLiteral => "unordered"
      has_attr 'aggregation', UML13::AggregationKind, :defaultValueLiteral => "none"
      has_attr 'targetScope', UML13::ScopeKind, :defaultValueLiteral => "instance"
      has_attr 'changeability', UML13::ChangeableKind, :defaultValueLiteral => "changeable"
   end

   class Interface < Classifier
   end

   class Constraint < ModelElement
   end

   class Relationship < ModelElement
   end

   class Association < RGen::MetamodelBuilder::MMMultiple(GeneralizableElement, Relationship)
   end

   class Attribute < StructuralFeature
   end

   class BehavioralFeature < Feature
      has_attr 'isQuery', Boolean
   end

   class Operation < BehavioralFeature
      has_attr 'concurrency', UML13::CallConcurrencyKind, :defaultValueLiteral => "sequential"
      has_attr 'isRoot', Boolean
      has_attr 'isLeaf', Boolean
      has_attr 'isAbstract', Boolean
   end

   class Parameter < ModelElement
      has_attr 'kind', UML13::ParameterDirectionKind, :defaultValueLiteral => "inout"
   end

   class Method < BehavioralFeature
   end

   class Generalization < Relationship
      has_attr 'discriminator', String
   end

   class AssociationClass < RGen::MetamodelBuilder::MMMultiple(Class, Association)
   end

   class Dependency < Relationship
   end

   class Abstraction < Dependency
   end

   class PresentationElement < Element
   end

   class Usage < Dependency
   end

   class Binding < Dependency
   end

   class Component < Classifier
   end

   class Node < Classifier
   end

   class Permission < Dependency
   end

   class Comment < ModelElement
      has_attr 'body', String
   end

   class Flow < Relationship
   end

   class TemplateParameter < RGen::MetamodelBuilder::MMBase
   end

   class ElementResidence < RGen::MetamodelBuilder::MMBase
      has_attr 'visibility', UML13::VisibilityKind, :defaultValueLiteral => "public"
   end

   class Multiplicity < RGen::MetamodelBuilder::MMBase
   end

   class Expression < RGen::MetamodelBuilder::MMBase
      has_attr 'language', String
      has_attr 'body', String
   end

   class ObjectSetExpression < Expression
   end

   class TimeExpression < Expression
   end

   class BooleanExpression < Expression
   end

   class ActionExpression < Expression
   end

   class MultiplicityRange < RGen::MetamodelBuilder::MMBase
      has_attr 'lower', String
      has_attr 'upper', String
   end

   class Structure < DataType
   end

   class Primitive < DataType
   end

   class Enumeration < DataType
   end

   class EnumerationLiteral < RGen::MetamodelBuilder::MMBase
      has_attr 'name', String
   end

   class ProgrammingLanguageType < DataType
   end

   class IterationExpression < Expression
   end

   class TypeExpression < Expression
   end

   class ArgListsExpression < Expression
   end

   class MappingExpression < Expression
   end

   class ProcedureExpression < Expression
   end

   class Stereotype < GeneralizableElement
      has_attr 'icon', String
      has_attr 'baseClass', String
   end

   class TaggedValue < Element
      has_attr 'tag', String
      has_attr 'value', String
   end

   class UseCase < Classifier
   end

   class Actor < Classifier
   end

   class Instance < ModelElement
   end

   class UseCaseInstance < Instance
   end

   class Extend < Relationship
   end

   class Include < Relationship
   end

   class ExtensionPoint < ModelElement
      has_attr 'location', String
   end

   class StateMachine < ModelElement
   end

   class Event < ModelElement
   end

   class StateVertex < ModelElement
   end

   class State < StateVertex
   end

   class TimeEvent < Event
   end

   class CallEvent < Event
   end

   class SignalEvent < Event
   end

   class Transition < ModelElement
   end

   class CompositeState < State
      has_attr 'isConcurrent', Boolean
   end

   class ChangeEvent < Event
   end

   class Guard < ModelElement
   end

   class Pseudostate < StateVertex
      has_attr 'kind', UML13::PseudostateKind, :defaultValueLiteral => "initial"
   end

   class SimpleState < State
   end

   class SubmachineState < CompositeState
   end

   class SynchState < StateVertex
      has_attr 'bound', Integer
   end

   class StubState < StateVertex
      has_attr 'referenceState', String
   end

   class FinalState < State
   end

   class Collaboration < RGen::MetamodelBuilder::MMMultiple(GeneralizableElement, Namespace)
   end

   class ClassifierRole < Classifier
   end

   class AssociationRole < Association
   end

   class AssociationEndRole < AssociationEnd
   end

   class Message < ModelElement
   end

   class Interaction < ModelElement
   end

   class Signal < Classifier
   end

   class Action < ModelElement
      has_attr 'isAsynchronous', Boolean
   end

   class CreateAction < Action
   end

   class DestroyAction < Action
   end

   class UninterpretedAction < Action
   end

   class AttributeLink < ModelElement
   end

   class Object < Instance
   end

   class Link < ModelElement
   end

   class LinkObject < RGen::MetamodelBuilder::MMMultiple(Object, Link)
   end

   class DataValue < Instance
   end

   class CallAction < Action
   end

   class SendAction < Action
   end

   class ActionSequence < Action
   end

   class Argument < ModelElement
   end

   class Reception < BehavioralFeature
      has_attr 'isPolymorphic', Boolean
      has_attr 'specification', String
   end

   class LinkEnd < ModelElement
   end

   class Call < RGen::MetamodelBuilder::MMBase
   end

   class ReturnAction < Action
   end

   class TerminateAction < Action
   end

   class Stimulus < ModelElement
   end

   class ActionInstance < RGen::MetamodelBuilder::MMBase
   end

   class Exception < Signal
   end

   class AssignmentAction < Action
   end

   class ComponentInstance < Instance
   end

   class NodeInstance < Instance
   end

   class ActivityGraph < StateMachine
   end

   class Partition < ModelElement
   end

   class SubactivityState < SubmachineState
      has_attr 'isDynamic', Boolean
   end

   class ActionState < SimpleState
      has_attr 'isDynamic', Boolean
   end

   class CallState < ActionState
   end

   class ObjectFlowState < SimpleState
      has_attr 'isSynch', Boolean
   end

   class ClassifierInState < Classifier
   end

   class Package < RGen::MetamodelBuilder::MMMultiple(GeneralizableElement, Namespace)
   end

   class Model < Package
   end

   class Subsystem < RGen::MetamodelBuilder::MMMultiple(Classifier, Package)
      has_attr 'isInstantiable', Boolean
   end

   class ElementImport < RGen::MetamodelBuilder::MMBase
      has_attr 'visibility', UML13::VisibilityKind, :defaultValueLiteral => "public"
      has_attr 'alias', String
   end

   class DiagramElement < PresentationElement
      has_attr 'geometry', String
      has_attr 'style', String
   end

   class Diagram < PresentationElement
      has_attr 'name', String
      has_attr 'toolName', String
      has_attr 'diagramType', String
      has_attr 'style', String
   end

end

UML13::Classifier.many_to_many 'participant', UML13::AssociationEnd, 'specification'
UML13::Classifier.one_to_many 'associationEnd', UML13::AssociationEnd, 'type'
UML13::Classifier.contains_many 'feature', UML13::Feature, 'owner'
UML13::StructuralFeature.contains_one_uni 'multiplicity', UML13::Multiplicity
UML13::StructuralFeature.has_one 'type', UML13::Classifier, :lowerBound => 1
UML13::Namespace.contains_many 'ownedElement', UML13::ModelElement, 'namespace'
UML13::AssociationEnd.contains_one_uni 'multiplicity', UML13::Multiplicity
UML13::AssociationEnd.contains_many 'qualifier', UML13::Attribute, 'associationEnd'
UML13::Association.contains_many 'connection', UML13::AssociationEnd, 'association', :lowerBound => 2
UML13::Constraint.contains_one_uni 'body', UML13::BooleanExpression
UML13::Constraint.many_to_many 'constrainedElement', UML13::ModelElement, 'constraint', :lowerBound => 1
UML13::GeneralizableElement.one_to_many 'specialization', UML13::Generalization, 'parent'
UML13::GeneralizableElement.one_to_many 'generalization', UML13::Generalization, 'child'
UML13::Attribute.contains_one_uni 'initialValue', UML13::Expression
UML13::Operation.one_to_many 'occurrence', UML13::CallEvent, 'operation'
UML13::Operation.one_to_many 'method', UML13::Method, 'specification'
UML13::Parameter.contains_one_uni 'defaultValue', UML13::Expression
UML13::Parameter.many_to_many 'state', UML13::ObjectFlowState, 'parameter'
UML13::Parameter.has_one 'type', UML13::Classifier, :lowerBound => 1
UML13::Method.contains_one_uni 'body', UML13::ProcedureExpression
UML13::BehavioralFeature.many_to_many 'raisedSignal', UML13::Signal, 'context'
UML13::BehavioralFeature.contains_many_uni 'parameter', UML13::Parameter
UML13::ModelElement.one_to_many 'behavior', UML13::StateMachine, 'context'
UML13::ModelElement.many_to_one 'stereotype', UML13::Stereotype, 'extendedElement'
UML13::ModelElement.one_to_many 'elementResidence', UML13::ElementResidence, 'resident'
UML13::ModelElement.many_to_many 'sourceFlow', UML13::Flow, 'source'
UML13::ModelElement.many_to_many 'targetFlow', UML13::Flow, 'target'
UML13::ModelElement.many_to_many 'presentation', UML13::PresentationElement, 'subject'
UML13::ModelElement.many_to_many 'supplierDependency', UML13::Dependency, 'supplier', :lowerBound => 1
UML13::ModelElement.contains_many 'taggedValue', UML13::TaggedValue, 'modelElement'
UML13::ModelElement.contains_many_uni 'templateParameter', UML13::TemplateParameter
UML13::ModelElement.many_to_many 'clientDependency', UML13::Dependency, 'client', :lowerBound => 1
UML13::ModelElement.many_to_many 'comment', UML13::Comment, 'annotatedElement'
UML13::ModelElement.one_to_many 'elementImport', UML13::ElementImport, 'modelElement'
UML13::Abstraction.contains_one_uni 'mapping', UML13::MappingExpression
UML13::Binding.has_many 'argument', UML13::ModelElement, :lowerBound => 1
UML13::Component.contains_many 'residentElement', UML13::ElementResidence, 'implementationLocation'
UML13::Component.many_to_many 'deploymentLocation', UML13::Node, 'resident'
UML13::TemplateParameter.has_one 'modelElement', UML13::ModelElement
UML13::TemplateParameter.has_one 'defaultElement', UML13::ModelElement
UML13::Multiplicity.contains_many_uni 'range', UML13::MultiplicityRange, :lowerBound => 1
UML13::Enumeration.contains_many_uni 'literal', UML13::EnumerationLiteral, :lowerBound => 1
UML13::ProgrammingLanguageType.contains_one_uni 'type', UML13::TypeExpression
UML13::Stereotype.has_many 'requiredTag', UML13::TaggedValue
UML13::UseCase.has_many 'extensionPoint', UML13::ExtensionPoint
UML13::UseCase.one_to_many 'include', UML13::Include, 'base'
UML13::UseCase.one_to_many 'extend', UML13::Extend, 'extension'
UML13::Extend.contains_one_uni 'condition', UML13::BooleanExpression
UML13::Extend.has_many 'extensionPoint', UML13::ExtensionPoint, :lowerBound => 1
UML13::Extend.has_one 'base', UML13::UseCase, :lowerBound => 1
UML13::Include.has_one 'addition', UML13::UseCase, :lowerBound => 1
UML13::StateMachine.contains_many_uni 'transitions', UML13::Transition
UML13::StateMachine.contains_one_uni 'top', UML13::State, :lowerBound => 1
UML13::Event.contains_many_uni 'parameters', UML13::Parameter
UML13::State.contains_one_uni 'doActivity', UML13::Action
UML13::State.contains_many_uni 'internalTransition', UML13::Transition
UML13::State.has_many 'deferrableEvent', UML13::Event
UML13::State.contains_one_uni 'exit', UML13::Action
UML13::State.contains_one_uni 'entry', UML13::Action
UML13::TimeEvent.contains_one_uni 'when', UML13::TimeExpression
UML13::SignalEvent.many_to_one 'signal', UML13::Signal, 'occurrence', :lowerBound => 1
UML13::Transition.many_to_one 'target', UML13::StateVertex, 'incoming', :lowerBound => 1
UML13::Transition.many_to_one 'source', UML13::StateVertex, 'outgoing', :lowerBound => 1
UML13::Transition.has_one 'trigger', UML13::Event
UML13::Transition.contains_one_uni 'effect', UML13::Action
UML13::Transition.contains_one_uni 'guard', UML13::Guard
UML13::CompositeState.contains_many 'subvertex', UML13::StateVertex, 'container', :lowerBound => 1
UML13::ChangeEvent.contains_one_uni 'changeExpression', UML13::BooleanExpression
UML13::Guard.contains_one_uni 'expression', UML13::BooleanExpression
UML13::SubmachineState.has_one 'submachine', UML13::StateMachine, :lowerBound => 1
UML13::Collaboration.has_one 'representedOperation', UML13::Operation
UML13::Collaboration.has_one 'representedClassifier', UML13::Classifier
UML13::Collaboration.has_many 'constrainingElement', UML13::ModelElement
UML13::Collaboration.contains_many 'interaction', UML13::Interaction, 'context'
UML13::ClassifierRole.contains_one_uni 'multiplicity', UML13::Multiplicity
UML13::ClassifierRole.has_many 'availableContents', UML13::ModelElement
UML13::ClassifierRole.has_many 'availableFeature', UML13::Feature
UML13::ClassifierRole.has_one 'base', UML13::Classifier, :lowerBound => 1
UML13::AssociationRole.contains_one_uni 'multiplicity', UML13::Multiplicity
UML13::AssociationRole.has_one 'base', UML13::Association
UML13::AssociationEndRole.has_many 'availableQualifier', UML13::Attribute
UML13::AssociationEndRole.has_one 'base', UML13::AssociationEnd
UML13::Message.has_one 'action', UML13::Action, :lowerBound => 1
UML13::Message.has_one 'communicationConnection', UML13::AssociationRole
UML13::Message.has_many 'predecessor', UML13::Message
UML13::Message.has_one 'receiver', UML13::ClassifierRole, :lowerBound => 1
UML13::Message.has_one 'sender', UML13::ClassifierRole, :lowerBound => 1
UML13::Message.has_one 'activator', UML13::Message
UML13::Interaction.contains_many 'message', UML13::Message, 'interaction', :lowerBound => 1
UML13::Interaction.contains_many_uni 'link', UML13::Link
UML13::Instance.contains_many_uni 'slot', UML13::AttributeLink
UML13::Instance.one_to_many 'linkEnd', UML13::LinkEnd, 'instance'
UML13::Instance.has_many 'classifier', UML13::Classifier, :lowerBound => 1
UML13::Signal.one_to_many 'reception', UML13::Reception, 'signal'
UML13::CreateAction.has_one 'instantiation', UML13::Classifier, :lowerBound => 1
UML13::Action.contains_one_uni 'recurrence', UML13::IterationExpression
UML13::Action.contains_one_uni 'target', UML13::ObjectSetExpression
UML13::Action.contains_one_uni 'script', UML13::ActionExpression
UML13::Action.contains_many_uni 'actualArgument', UML13::Argument
UML13::AttributeLink.has_one 'value', UML13::Instance, :lowerBound => 1
UML13::AttributeLink.has_one 'attribute', UML13::Attribute, :lowerBound => 1
UML13::CallAction.has_one 'operation', UML13::Operation, :lowerBound => 1
UML13::SendAction.has_one 'signal', UML13::Signal, :lowerBound => 1
UML13::ActionSequence.contains_many_uni 'action', UML13::Action
UML13::Argument.contains_one_uni 'value', UML13::Expression
UML13::Link.contains_many_uni 'connection', UML13::LinkEnd, :lowerBound => 2
UML13::Link.has_one 'association', UML13::Association, :lowerBound => 1
UML13::LinkEnd.has_one 'associationEnd', UML13::AssociationEnd, :lowerBound => 1
UML13::LinkEnd.has_one 'participant', UML13::Instance, :lowerBound => 1
UML13::Stimulus.has_one 'dispatchAction', UML13::Action, :lowerBound => 1
UML13::Stimulus.has_one 'communicationLink', UML13::Link
UML13::Stimulus.has_one 'receiver', UML13::Instance, :lowerBound => 1
UML13::Stimulus.has_one 'sender', UML13::Instance, :lowerBound => 1
UML13::Stimulus.has_many 'argument', UML13::Instance
UML13::ComponentInstance.has_many 'resident', UML13::Instance
UML13::NodeInstance.has_many 'resident', UML13::ComponentInstance
UML13::ActivityGraph.contains_many_uni 'partition', UML13::Partition
UML13::Partition.has_many 'contents', UML13::ModelElement
UML13::SubactivityState.contains_one_uni 'dynamicArguments', UML13::ArgListsExpression
UML13::ObjectFlowState.has_one 'type', UML13::Classifier, :lowerBound => 1
UML13::ObjectFlowState.has_one 'available', UML13::Parameter, :lowerBound => 1
UML13::ClassifierInState.has_one 'type', UML13::Classifier, :lowerBound => 1
UML13::ClassifierInState.has_many 'inState', UML13::State
UML13::ActionState.contains_one_uni 'dynamicArguments', UML13::ArgListsExpression
UML13::Package.contains_many 'importedElement', UML13::ElementImport, 'package'
UML13::Diagram.contains_many 'element', UML13::DiagramElement, 'diagram'
UML13::Diagram.has_one 'owner', UML13::ModelElement, :lowerBound => 1
