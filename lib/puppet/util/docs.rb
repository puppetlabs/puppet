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

    attr_writer :doc

    # Generate the full doc string.
    def doc
        extra = methods.find_all { |m| m.to_s =~ /^dochook_.+/ }.sort.collect { |m|
            self.send(m)
        }.join("  ")

        if defined? @doc and @doc
            @doc + extra
        else
            extra
        end
    end

    # Build a table
    def doctable(headers, data)
        str = "\n\n"

        lengths = []
        # Figure out the longest field for all columns
        data.each do |name, values|
            [name, values].flatten.each_with_index do |value, i|
                lengths[i] ||= 0
                lengths[i] = value.to_s.length if value.to_s.length > lengths[i]
            end
        end

        # The headers could also be longest
        headers.each_with_index do |value, i|
            lengths[i] = value.to_s.length if value.to_s.length > lengths[i]
        end

        # Add the top header row
        str += lengths.collect { |num| "=" * num }.join(" ") + "\n"

        # And the header names
        str += headers.zip(lengths).collect { |value, num| pad(value, num) }.join(" ") + "\n"

        # And the second header row
        str += lengths.collect { |num| "=" * num }.join(" ") + "\n"

        # Now each data row
        data.sort { |a, b| a[0].to_s <=> b[0].to_s }.each do |name, rows|
            str += [name, rows].flatten.zip(lengths).collect do |value, length|
                pad(value, length)
            end.join(" ") + "\n"
        end

        # And the bottom line row
        str += lengths.collect { |num| "=" * num }.join(" ") + "\n"

        str + "\n"
    end

    attr_reader :nodoc
    def nodoc?
        nodoc
    end

    # Pad a field with spaces
    def pad(value, length)
        value.to_s + (" " * (length - value.to_s.length))
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
        # indent from every line.  However, ignore any indentation on the
        # first line, since that can be inconsistent.
        text = text.lstrip()
        text.gsub!(/^([\t]+)/) { |s| " "*8*s.length(); } # Expand leading tabs
        # Find first non-empty line after the first line:
        line2start = (text =~ /(\n?\s*\n)/)
        line2start += $1.length
        if (text[line2start..-1] =~ /^([ ]+)\S/) == 0
            indent = Regexp.quote($1)
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

