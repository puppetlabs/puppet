require 'time'
require 'puppet/network/format_support'
require 'puppet/util/psych_support'

module Puppet
  class Resource

    # This class represents the result of evaluating a given resource. It
    # contains file and line information about the source, events generated
    # while evaluating the resource, timing information, and the status of the
    # resource evaluation.
    #
    # @api private
    class Status
      include Puppet::Util::PsychSupport
      include Puppet::Util::Tagging
      include Puppet::Network::FormatSupport

      # @!attribute [rw] file
      #   @return [String] The file where `@real_resource` was defined.
      attr_accessor :file

      # @!attribute [rw] line
      #   @return [Integer] The line number in the file where `@real_resource` was defined.
      attr_accessor :line

      # @!attribute [rw] evaluation_time
      #   @return [Float] The time elapsed in sections while evaluating `@real_resource`.
      #     measured in seconds.
      attr_accessor :evaluation_time

      # Boolean status types set while evaluating `@real_resource`.
      STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled]
      attr_accessor *STATES

      # @!attribute [r] source_description
      #   @return [String] The textual description of the path to `@real_resource`
      #     based on the containing structures. This is in contrast to
      #     `@containment_path` which is a list of containment path components.
      #   @example
      #     status.source_description #=> "/Stage[main]/Myclass/Exec[date]"
      attr_reader :source_description

      # @!attribute [r] containment_path
      #   @return [Array<String>] A list of resource references that contain
      #     `@real_resource`.
      #   @example A normal contained type
      #     status.containment_path #=> ["Stage[main]", "Myclass", "Exec[date]"]
      #   @example A whit associated with a class
      #     status.containment_path #=> ["Whit[Admissible_class[Main]]"]
      attr_reader :containment_path

      # @!attribute [r] time
      #   @return [Time] The time that this status object was created
      attr_reader :time

      # @!attribute [r] resource
      #   @return [String] The resource reference for `@real_resource`
      attr_reader :resource

      # @!attribute [r] change_count
      #   @return [Integer] A count of the successful changes made while
      #     evaluating `@real_resource`.
      attr_reader :change_count

      # @!attribute [r] out_of_sync_count
      #   @return [Integer] A count of the audited changes made while
      #     evaluating `@real_resource`.
      attr_reader :out_of_sync_count

      # @!attribute [r] resource_type
      #   @example
      #     status.resource_type #=> 'Notify'
      #   @return [String] The class name of `@real_resource`
      attr_reader :resource_type

      # @!attribute [r] title
      #   @return [String] The title of `@real_resource`
      attr_reader :title

      # @!attribute [r] events
      #   @return [Array<Puppet::Transaction::Event>] A list of events generated
      #     while evaluating `@real_resource`.
      attr_reader :events

      # @!attribute [rw] failed_dependencies
      #   @return [Array<Puppet::Resource>] A cache of all
      #   dependencies of this resource that failed to apply.
      attr_accessor :failed_dependencies

      def dependency_failed?
        failed_dependencies && !failed_dependencies.empty?
      end

      # A list of instance variables that should be serialized with this object
      # when converted to YAML.
      YAML_ATTRIBUTES = %w{@resource @file @line @evaluation_time @change_count
                           @out_of_sync_count @tags @time @events @out_of_sync
                           @changed @resource_type @title @skipped @failed
                           @containment_path}.
        map(&:to_sym)

      def self.from_data_hash(data)
        obj = self.allocate
        obj.initialize_from_hash(data)
        obj
      end

      # Provide a boolean method for each of the states.
      STATES.each do |attr|
        define_method("#{attr}?") do
          !! send(attr)
        end
      end

      def <<(event)
        add_event(event)
        self
      end

      def add_event(event)
        @events << event
        if event.status == 'failure'
          self.failed = true
        elsif event.status == 'success'
          @change_count += 1
          @changed = true
        end
        if event.status != 'audit'
          @out_of_sync_count += 1
          @out_of_sync = true
        end
      end

      def failed_because(detail)
        @real_resource.log_exception(detail, "Could not evaluate: #{detail}")
        failed = true
        # There's a contract (implicit unfortunately) that a status of failed
        # will always be accompanied by an event with some explanatory power.  This
        # is useful for reporting/diagnostics/etc.  So synthesize an event here
        # with the exception detail as the message.
        add_event(@real_resource.event(:name => :resource_error, :status => "failure", :message => detail.to_s))
      end

      def initialize(resource)
        @real_resource = resource
        @source_description = resource.path
        @containment_path = resource.pathbuilder
        @resource = resource.to_s
        @change_count = 0
        @out_of_sync_count = 0
        @changed = false
        @out_of_sync = false
        @skipped = false
        @failed = false

        @file = resource.file
        @line = resource.line

        tag(*resource.tags)
        @time = Time.now
        @events = []
        @resource_type = resource.type.to_s.capitalize
        @title = resource.title
      end

      def initialize_from_hash(data)
        @resource_type = data['resource_type']
        @title = data['title']
        @resource = data['resource']
        @containment_path = data['containment_path']
        @file = data['file']
        @line = data['line']
        @evaluation_time = data['evaluation_time']
        @change_count = data['change_count']
        @out_of_sync_count = data['out_of_sync_count']
        @tags = Puppet::Util::TagSet.new(data['tags'])
        @time = data['time']
        @time = Time.parse(@time) if @time.is_a? String
        @out_of_sync = data['out_of_sync']
        @changed = data['changed']
        @skipped = data['skipped']
        @failed = data['failed']

        @events = data['events'].map do |event|
          # in YAML (for reports) we serialize this as an object, but
          # in PSON it becomes a hash. Depending on where we came from
          # we might not need to deserialize it.
          if event.class == Puppet::Transaction::Event
            event
          else
            Puppet::Transaction::Event.from_data_hash(event)
          end
        end
      end

      def to_data_hash
        {
          'title' => @title,
          'file' => @file,
          'line' => @line,
          'resource' => @resource,
          'resource_type' => @resource_type,
          'containment_path' => @containment_path,
          'evaluation_time' => @evaluation_time,
          'tags' => @tags.to_a,
          'time' => @time.iso8601(9),
          'failed' => @failed,
          'changed' => @changed,
          'out_of_sync' => @out_of_sync,
          'skipped' => @skipped,
          'change_count' => @change_count,
          'out_of_sync_count' => @out_of_sync_count,
          'events' => @events,
        }
      end

      def to_yaml_properties
        YAML_ATTRIBUTES & super
      end
    end
  end
end
