module Puppet # :nodoc:
    # The base class for all Puppet errors.  We want to make it easy to add
    # line and file information.  This probably isn't necessary for all
    # errors, but...
    class Error < RuntimeError
        attr_accessor :line, :file

        def backtrace
            if defined? @backtrace
                return @backtrace
            else
                return super
            end
        end

        def initialize(message, line = nil, file = nil)
            @message = message

            @line = line if line
            @file = file if file
        end

        def to_s
            str = nil
            if self.file and self.line
                str = "%s at %s:%s" %
                    [@message.to_s, @file, @line]
            elsif self.line
                str = "%s at line %s" %
                    [@message.to_s, @line]
            elsif self.file
                str = "%s in %s" % [@message.to_s, self.file]
            else
                str = @message.to_s
            end

            return str
        end
    end

    # An error class for when I don't know what happened.  Automatically
    # prints a stack trace when in debug mode.
    class DevError < Puppet::Error
    end
end
