# -*- coding: utf-8 -*-
require 'puppet'
require 'puppet/util/log'
require 'puppet/util/metric'
require 'puppet/property'
require 'puppet/parameter'
require 'puppet/util'
require 'puppet/util/autoload'
require 'puppet/metatype/manager'
require 'puppet/util/errors'
require 'puppet/util/logging'
require 'puppet/util/tagging'

require 'puppet/type_guts/app_orchestration'
require 'puppet/type_guts/automatic_relationships'
require 'puppet/type_guts/attribute_values'
require 'puppet/type_guts/comparable'
require 'puppet/type_guts/creating_attributes'
require 'puppet/type_guts/device_applicability'
require 'puppet/type_guts/key_attributes'
require 'puppet/type_guts/newtype_dsl'
require 'puppet/type_guts/provider'
require 'puppet/type_guts/querying_attributes_original'
require 'puppet/type_guts/structure'
require 'puppet/type_guts/system_interaction'
require 'puppet/type_guts/utilities'

# these need to go last, since they rely on all the infrastructure being in place
require 'puppet/type_guts/attribute_definitions'

module Puppet
  # The base class for all Puppet types.
  #
  # A type describes:
  #--
  # * **Attributes** - properties, parameters, and meta-parameters are different types of attributes of a type.
  #   * **Properties** - these are the properties of the managed resource (attributes of the entity being managed; like
  #     a file's owner, group and mode). A property describes two states; the 'is' (current state) and the 'should' (wanted
  #     state).
  #       * **Ensurable** - a set of traits that control the lifecycle (create, remove, etc.) of a managed entity.
  #         There is a default set of operations associated with being _ensurable_, but this can be changed.
  #       * **Name/Identity** - one property is the name/identity of a resource, the _namevar_ that uniquely identifies
  #         one instance of a type from all others.
  #   * **Parameters** - additional attributes of the type (that does not directly related to an instance of the managed
  #     resource; if an operation is recursive or not, where to look for things, etc.). A Parameter (in contrast to Property)
  #     has one current value where a Property has two (current-state and wanted-state).
  #   * **Meta-Parameters** - parameters that are available across all types. A meta-parameter typically has
  #     additional semantics; like the `require` meta-parameter. A new type typically does not add new meta-parameters,
  #     but you need to be aware of their existence so you do not inadvertently shadow an existing meta-parameters.
  # * **Parent** - a type can have a super type (that it inherits from).
  # * **Validation** - If not just a basic data type, or an enumeration of symbolic values, it is possible to provide
  #     validation logic for a type, properties and parameters.
  # * **Munging** - munging/unmunging is the process of turning a value in external representation (as used
  #     by a provider) into an internal representation and vice versa. A Type supports adding custom logic for these.
  # * **Auto Requirements** - a type can specify automatic relationships to resources to ensure that if they are being
  #     managed, they will be processed before this type.
  # * **Providers** - a provider is an implementation of a type's behavior - the management of a resource in the
  #     system being managed. A provider is often platform specific and is selected at runtime based on
  #     criteria/predicates specified in the configured providers. See {Puppet::Provider} for details.
  # * **Device Support** - A type has some support for being applied to a device; i.e. something that is managed
  #     by running logic external to the device itself. There are several methods that deals with type
  #     applicability for these special cases such as {apply_to_device}.
  #
  # Additional Concepts:
  # --
  # * **Resource-type** - A _resource type_ is a term used to denote the type of a resource; internally a resource
  #     is really an instance of a Ruby class i.e. {Puppet::Resource} which defines its behavior as "resource data".
  #     Conceptually however, a resource is an instance of a subclass of Type (e.g. File), where such a class describes
  #     its interface (what can be said/what is known about a resource of this type),
  # * **Managed Entity** - This is not a term in general use, but is used here when there is a need to make
  #     a distinction between a resource (a description of what/how something should be managed), and what it is
  #     managing (a file in the file system). The term _managed entity_ is a reference to the "file in the file system"
  # * **Isomorphism** - the quality of being _isomorphic_ means that two resource instances with the same name
  #     refers to the same managed entity. Or put differently; _an isomorphic name is the identity of a resource_.
  #     As an example, `exec` resources (that executes some command) have the command (i.e. the command line string) as
  #     their name, and these resources are said to be non-isomorphic.
  #
  # @note The Type class deals with multiple concerns; some methods provide an internal DSL for convenient definition
  #   of types, other methods deal with various aspects while running; wiring up a resource (expressed in Puppet DSL)
  #   with its _resource type_ (i.e. an instance of Type) to enable validation, transformation of values
  #   (munge/unmunge), etc. Lastly, Type is also responsible for dealing with Providers; the concrete implementations
  #   of the behavior that constitutes how a particular Type behaves on a particular type of system (e.g. how
  #   commands are executed on a flavor of Linux, on Windows, etc.). This means that as you are reading through the
  #   documentation of this class, you will be switching between these concepts, as well as switching between
  #   the conceptual level "a resource is an instance of a resource-type" and the actual implementation classes
  #   (Type, Resource, Provider, and various utility and helper classes).
  #
  # @api public
  #
  class Type
    # this only is here to attach the above YARDoc correctly
  end
end