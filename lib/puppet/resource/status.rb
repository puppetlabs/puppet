module Puppet
  class Resource
    class Status
      include Puppet::Util::Tagging
      include Puppet::Util::Logging

      attr_accessor :resource, :node, :file, :line, :current_values, :status, :evaluation_time

      STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled]
      attr_accessor *STATES

      attr_reader :source_description, :default_log_level, :time, :resource
      attr_reader :change_count, :out_of_sync_count, :resource_type, :title

      YAML_ATTRIBUTES = %w{@resource @file @line @evaluation_time @change_count @out_of_sync_count @tags @time @events @out_of_sync @changed @resource_type @title @skipped @failed}


      def self.from_pson(data)
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

      def events
        @events
      end

      def initialize(resource)
        @source_description = resource.path
        @resource = resource.to_s
        @change_count = 0
        @out_of_sync_count = 0
        @changed = false
        @out_of_sync = false
        @skipped = false
        @failed = false

        [:file, :line].each do |attr|
          send(attr.to_s + "=", resource.send(attr))
        end

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
        @file = data['file']
        @line = data['line']
        @evaluation_time = data['evaluation_time']
        @change_count = data['change_count']
        @out_of_sync_count = data['out_of_sync_count']
        @tags = data['tags']
        @time = data['time']
        @out_of_sync = data['out_of_sync']
        @changed = data['changed']
        @skipped = data['skipped']
        @failed = data['failed']

        @events = data['events'].map do |event|
          Puppet::Transaction::Event.from_pson(event)
        end
      end

      def to_yaml_properties
        YAML_ATTRIBUTES & instance_variables
      end

      private

      def log_source
        source_description
      end
    end
  end
end
