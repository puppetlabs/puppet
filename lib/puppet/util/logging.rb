# A module to make logging a bit easier.
require 'puppet/util/log'

module Puppet::Util::Logging

    def send_log(level, message)
        Puppet::Util::Log.create({:level => level, :source => log_source(), :message => message}.merge(log_metadata))
    end

    # Create a method for each log level.
    Puppet::Util::Log.eachlevel do |level|
        define_method(level) do |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            send_log(level, args)
        end
    end

    private

    def is_resource?
        defined?(Puppet::Type) && is_a?(Puppet::Type)
    end

    def is_resource_parameter?
        defined?(Puppet::Parameter) && is_a?(Puppet::Parameter)
    end

    def log_metadata
        [:file, :line, :version, :tags].inject({}) do |result, attr|
            result[attr] = send(attr) if respond_to?(attr)
            result
        end
    end

    def log_source
        # We need to guard the existence of the constants, since this module is used by the base Puppet module.
        (is_resource? or is_resource_parameter?) and respond_to?(:path) and return path.to_s
        return to_s
    end
end
