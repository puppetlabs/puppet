  # Static Loader contains constants, basic data types and other types required for the system
  # to boot.
  #
module Puppet::Pops
module Loader
class StaticLoader < Loader

  BUILTIN_TYPE_NAMES = %w{
      Augeas
      Component
      Computer
      Cron
      Exec
      File
      Filebucket
      Group
      Host
      Interface
      K5login
      Macauthorization
      Mailalias
      Maillist
      Mcx
      Mount
      Nagios_command
      Nagios_contact
      Nagios_contactgroup
      Nagios_host
      Nagios_hostdependency
      Nagios_hostescalation
      Nagios_hostgroup
      Nagios_hostextinfo
      Nagios_service
      Nagios_servicedependency
      Nagios_serviceescalation
      Nagios_serviceextinfo
      Nagios_servicegroup
      Nagios_timeperiod
      Node
      Notify
      Package
      Resources
      Router
      Schedule
      Scheduled_task
      Selboolean
      Selmodule
      Service
      Ssh_authorized_key
      Sshkey
      Stage
      Tidy
      User
      Vlan
      Whit
      Yumrepo
      Zfs
      Zone
      Zpool
    }.freeze

  BUILTIN_TYPE_NAMES_LC = Set.new(BUILTIN_TYPE_NAMES.map { |n| n.downcase }).freeze

  BUILTIN_ALIASES = {
    'Data' => 'Variant[ScalarData,Undef,Hash[String,Data],Array[Data]]',
    'RichDataKey' => 'Variant[String,Numeric]',
    'RichData' => 'Variant[Scalar,SemVerRange,Binary,Sensitive,Type,TypeSet,URI,Object,Undef,Default,Hash[RichDataKey,RichData],Array[RichData]]',

    # Backward compatible aliases.
    'Puppet::LookupKey' => 'RichDataKey',
    'Puppet::LookupValue' => 'RichData'
  }.freeze

  attr_reader :loaded
  def initialize
    @loaded = {}
    @runtime_3_initialized = false
    create_built_in_types
  end

  def discover(type, error_collector = nil, name_authority = Pcore::RUNTIME_NAME_AUTHORITY)
    # Static loader only contains runtime types
    return EMPTY_ARRAY unless type == :type && name_authority == name_authority = Pcore::RUNTIME_NAME_AUTHORITY

    typed_names = type == :type && name_authority == Pcore::RUNTIME_NAME_AUTHORITY ? @loaded.keys : EMPTY_ARRAY
    block_given? ? typed_names.select { |tn| yield(tn) } : typed_names
  end

  def load_typed(typed_name)
    load_constant(typed_name)
  end

  def get_entry(typed_name)
    load_constant(typed_name)
  end

  def set_entry(typed_name, value, origin = nil)
    @loaded[typed_name] = Loader::NamedEntry.new(typed_name, value, origin)
  end

  def find(name)
    # There is nothing to search for, everything this loader knows about is already available
    nil
  end

  def parent
    nil # at top of the hierarchy
  end

  def to_s()
    "(StaticLoader)"
  end

  def loaded_entry(typed_name, check_dependencies = false)
    @loaded[typed_name]
  end

  def runtime_3_init
    unless @runtime_3_initialized
      @runtime_3_initialized = true
      create_resource_type_references
    end
    nil
  end

  def register_aliases
    aliases = BUILTIN_ALIASES.map { |name, string| add_type(name, Types::PTypeAliasType.new(name, Types::TypeFactory.type_reference(string), nil)) }
    aliases.each { |type| type.resolve(self) }
  end

  private

  def load_constant(typed_name)
    @loaded[typed_name]
  end

  def create_built_in_types
    origin_uri = URI("puppet:Puppet-Type-System/Static-Loader")
    type_map = Puppet::Pops::Types::TypeParser.type_map
    type_map.each do |name, type|
      set_entry(TypedName.new(:type, name), type, origin_uri)
    end
  end

  def create_resource_type_references()
    # These needs to be done quickly and we do not want to scan the file system for these
    # We are also not interested in their definition only that they exist.
    # These types are in all environments.
    #
    BUILTIN_TYPE_NAMES.each { |name| create_resource_type_reference(name) }
  end

  def add_type(name, type)
    set_entry(TypedName.new(:type, name), type)
    type
  end

  def create_resource_type_reference(name)
    add_type(name, Types::TypeFactory.resource(name))
  end
end
end
end
