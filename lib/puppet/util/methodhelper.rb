# Where we store helper methods related to, um, methods.
module Puppet::Util::MethodHelper
    # Take a hash and convert all of the keys to symbols if possible.
    def symbolize_options(options)
        options.inject({}) do |hash, opts|
            if opts[0].respond_to? :intern
                hash[opts[0].intern] = opts[1]
            else
                hash[opts[0]] = opts[1]
            end
            hash
        end
    end
end

# $Id$
