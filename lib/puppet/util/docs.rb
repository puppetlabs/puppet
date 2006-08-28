# Some simple methods for helping manage automatic documentation generation.
module Puppet::Util::Docs
    # Specify the actual doc string.
    def desc(str)
        @doc = str
    end

    # Add a new autodoc block.  We have to define these as class methods,
    # rather than just sticking them in a hash, because otherwise they're
    # too difficult to do inheritance with.
    def dochook(name, &block)
        method = "dochook_" + name.to_s

        meta_def method, &block
    end

    # Generate the full doc string.
    def doc
        extra = methods.find_all { |m| m.to_s =~ /^dochook_.+/ }.collect { |m|
            self.send(m)
        }.join("  ")

        @doc + extra
    end
end

# $Id$
