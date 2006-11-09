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

        if defined? @doc and @doc
            @doc + extra
        else
            extra
        end
    end

    # Handle the inline indentation in the docs.
    def scrub(text)
        # Stupid markdown
        #text = text.gsub("<%=", "&lt;%=")
        # For text with no carriage returns, there's nothing to do.
        if text !~ /\n/
            return text
        end
        indent = nil

        # If we can match an indentation, then just remove that same level of
        # indent from every line.
        if text =~ /^(\s+)/
            indent = $1
            begin
                return text.gsub(/^#{indent}/,'')
            rescue => detail
                puts detail.backtrace
                puts detail
            end
        else
            return text
        end

    end

    module_function :scrub
end

# $Id$
