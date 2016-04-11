  # Static Loader contains constants, basic data types and other types required for the system
  # to boot.
  #
module Puppet::Pops
module Loader
class StaticLoader < Loader

  attr_reader :loaded
  def initialize
    @loaded = {}
    create_logging_functions()
    create_built_in_types()
    create_resource_type_references()
  end

  def load_typed(typed_name)
    load_constant(typed_name)
  end

  def get_entry(typed_name)
    load_constant(typed_name)
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

  def loaded_entry(typed_name, _)
    @loaded[typed_name]
  end

  private

  def load_constant(typed_name)
    @loaded[typed_name]
  end

  # Creates a function for each of the specified log levels
  #
  def create_logging_functions()
    Puppet::Util::Log.levels.each do |level|

      fc = Puppet::Functions.create_function(level) do
        # create empty dispatcher to stop it from complaining about missing method since
        # an override of :call is made instead of using dispatch.
        dispatch(:log) { }

        # Logs per the specified level, outputs formatted information for arrays, hashes etc.
        # Overrides the implementation in Function that uses dispatching. This is not needed here
        # since it accepts 0-n Object.
        #
        define_method(:call) do |scope, *vals|
          # NOTE: 3x, does this: vals.join(" ")
          # New implementation uses the evaluator to get proper formatting per type
          # TODO: uses a fake scope (nil) - fix when :scopes are available via settings
          mapped = vals.map {|v| Puppet::Pops::Evaluator::EvaluatorImpl.new.string(v, nil) }

          # Bypass Puppet.<level> call since it picks up source from "self" which is not applicable in the 4x
          # Function API.
          # TODO: When a function can obtain the file, line, pos of the call merge those in (3x supports
          #       options :file, :line. (These were never output when calling the 3x logging functions since
          #       3x scope does not know about the calling location at that detailed level, nor do they
          #       appear in a report to stdout/error when included). Now, the output simply uses scope (like 3x)
          #       as this is good enough, but does not reflect the true call-stack, but is a rough estimate
          #       of where the logging call originates from).
          #
          Puppet::Util::Log.create({:level => level, :source => scope, :message => mapped.join(" ")})
        end
      end

      typed_name = TypedName.new(:function, level)
      # TODO:closure scope is fake (an empty hash) - waiting for new global scope to be available via lookup of :scopes
      func = fc.new({},self)
      @loaded[ typed_name ] = NamedEntry.new(typed_name, func, __FILE__)
    end
  end

  def create_built_in_types
    origin_uri = URI("puppet:Puppet-Type-System/Static-Loader")
    type_map = Puppet::Pops::Types::TypeParser.type_map
    type_map.each do |name, type|
      typed_name = TypedName.new(:type, name)
      @loaded[ typed_name ] = NamedEntry.new(typed_name, type, origin_uri)#__FILE__)
    end
  end

  def create_resource_type_references()
    # These needs to be done quickly and we do not want to scan the file system for these
    # We are also not interested in their definition only that they exist.
    # These types are in all environments.
    #
    %w{
      Auegas
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
    }.each { |name| create_resource_type_reference(name) }

    if Puppet[:app_management]
      create_resource_type_reference('Node')
    end
  end

  def create_resource_type_reference(name)
    typed_name = TypedName.new(:type, name.downcase)
    type = Puppet::Pops::Types::TypeFactory.resource(name)
    @loaded[ typed_name ] = NamedEntry.new(typed_name, type, __FILE__)
  end
end
end
end
