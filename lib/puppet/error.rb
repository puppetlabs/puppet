module Puppet
  # The base class for all Puppet errors. It can wrap another exception
  class Error < RuntimeError
    attr_reader :original
    def initialize(message, original=nil)
      super(message)
      @original = original
    end
  end

  module ExternalFileError
    # This module implements logging with a filename and line number. Use this
    # for errors that need to report a location in a non-ruby file that we
    # parse.
    attr_accessor :line, :file

    def initialize(message, file=nil, line=nil, original=nil)
      super(message, original)
      @file = file
      @line = line
    end

    def to_s
      msg = super
      if @file and @line
        "#{msg} at #{@file}:#{@line}"
      elsif @line
        "#{msg} at line #{@line}"
      elsif @file
        "#{msg} in #{@file}"
      else
        msg
      end
    end
  end

  class ParseError < Puppet::Error
    include ExternalFileError
  end

  class ResourceError < Puppet::Error
    include ExternalFileError
  end

  # An error class for when I don't know what happened.  Automatically
  # prints a stack trace when in debug mode.
  class DevError < Puppet::Error
  end
end
