# A module to make logging a bit easier.
require 'puppet/log'

module Puppet::Util::Logging
    # Create a method for each log level.
    Puppet::Log.eachlevel do |level|
        define_method(level) do |args|
            if args.is_a?(Array)
                args = args.join(" ")
            end
            Puppet::Log.create(
                :level => level,
                :source => self,
                :message => args
            )
        end
    end
end

# $Id$
