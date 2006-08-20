module Puppet # :nodoc:
    # The base class for all Puppet errors.  We want to make it easy to add
    # line and file information.  This probably isn't necessary for all
    # errors, but...
    class Error < RuntimeError
        attr_accessor :line, :file
        attr_writer :backtrace

        def backtrace
            if defined? @backtrace
                return @backtrace
            else
                return super
            end
        end

        def initialize(message)
            @message = message
        end

        def to_s
            str = nil
            if defined? @file and defined? @line and @file and @line
                str = "%s in file %s at line %s" %
                    [@message.to_s, @file, @line]
            elsif defined? @line and @line
                str = "%s at line %s" %
                    [@message.to_s, @line]
            else
                str = @message.to_s
            end

            return str
        end
    end

    class DevError < Error; end
end

# $Id$
