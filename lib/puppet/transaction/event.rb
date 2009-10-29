require 'puppet'

# A simple struct for storing what happens on the system.
Puppet::Transaction::Event = Struct.new(:name, :resource, :property, :result, :log, :previous_value, :desired_value) do
    def to_s
        log
    end
end
