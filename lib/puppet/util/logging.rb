# A module to make logging a bit easier.
require 'puppet/util/log'

module Puppet::Util::Logging
    # Create a method for each log level.
    Puppet::Util::Log.eachlevel do |level|
        define_method(level) do |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            Puppet::Util::Log.create(
                :level => level,
                :source => self,
                :message => args
            )
        end
    end
end

