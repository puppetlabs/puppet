require 'time'
require 'puppet/network/format_support'

module Puppet
  class Resource
    class Status
      include Puppet::Util::Tagging
      include Puppet::Util::Logging
      include Puppet::Network::FormatSupport

      attr_accessor :resource, :node, :file, :line, :current_values, :status, :evaluation_time

      STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled]
      attr_accessor *STATES

      attr_reader :source_description, :containment_path,
                  :default_log_level, :time, :resource, :change_count,
                  :out_of_sync_count, :resource_type, :title

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

      def self.from_pson(data)
        Puppet.deprecation_warning("from_pson is being removed in favour of from_data_hash.")
        self.from_data_hash(data)
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

      def events
        @events
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
          Puppet::Transaction::Event.from_data_hash(event)
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
          'tags' => @tags,
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

      private

      def log_source
        source_description
      end
    end
  end
end
