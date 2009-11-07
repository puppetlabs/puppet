require 'puppet/transaction'
require 'puppet/util/tagging'
require 'puppet/util/logging'

# A simple struct for storing what happens on the system.
class Puppet::Transaction::Event 
    include Puppet::Util::Tagging
    include Puppet::Util::Logging

    ATTRIBUTES = [:name, :resource, :property, :previous_value, :desired_value, :status, :message, :node, :version, :file, :line, :source_description]
    attr_accessor *ATTRIBUTES
    attr_writer :tags
    attr_accessor :time

    EVENT_STATUSES = %w{noop success failure}

    def initialize(*args)
        options = args.last.is_a?(Hash) ? args.pop : ATTRIBUTES.inject({}) { |hash, attr| hash[attr] = args.pop; hash }
        options.each { |attr, value| send(attr.to_s + "=", value) unless value.nil? }
        
        @time = Time.now
    end

    def property=(prop)
        @property = prop.to_s
    end

    def resource=(res)
        @resource = res.to_s
    end

    def send_log
        super(status == "failure" ? :err : :notice, message)
    end

    def status=(value)
        raise ArgumentError, "Event status can only be #{EVENT_STATUSES.join(', ')}" unless EVENT_STATUSES.include?(value)
        @status = value
    end

    def to_s
        message
    end

    private

    # Used by the Logging module
    def log_source
        source_description || property || resource
    end
end
