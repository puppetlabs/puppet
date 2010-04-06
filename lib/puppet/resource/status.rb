class Puppet::Resource::Status
    include Puppet::Util::Tagging
    include Puppet::Util::Logging

    ATTRIBUTES = [:resource, :node, :version, :file, :line, :current_values, :skipped_reason, :status, :evaluation_time, :change_count]
    attr_accessor *ATTRIBUTES

    STATES = [:skipped, :failed, :failed_to_restart, :restarted, :changed, :out_of_sync, :scheduled]
    attr_accessor *STATES

    attr_reader :source_description, :default_log_level, :time, :resource

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
        end
    end

    def events
        @events
    end

    def initialize(resource)
        @source_description = resource.path
        @resource = resource.to_s

        [:file, :line, :version].each do |attr|
            send(attr.to_s + "=", resource.send(attr))
        end

        tag(*resource.tags)
        @time = Time.now
        @events = []
    end

    private

    def log_source
        source_description
    end
end
