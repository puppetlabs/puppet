module Puppet
  # The base class for all Puppet errors. It can wrap another exception
  class Error < RuntimeError
    attr_accessor :original
    def initialize(message, original=nil)
      super(message)
      @original = original
    end
  end

  module ExternalFileError
    # This module implements logging with a filename and line number. Use this
    # for errors that need to report a location in a non-ruby file that we
    # parse.
    attr_accessor :file, :issue_code, :environment, :node
    attr_reader :line, :pos

    # Creates an error that contains external file information and optional issue code
    #
    # @param message [String] The error message
    # @param file [String] Path to the file where the error was found
    # @param line [Integer,String] The line number in the _file_
    # @param pos [Integer,String] The position on the _line_
    # @param original [Exception] Original exception
    # @param issue_code [Symbol]
    #
    # @see Puppet::Pops::Issues::Issue
    #
    def initialize(message, file=nil, line=nil, pos=nil, original=nil, issue_code=nil)
      if pos.kind_of? Exception
        original = pos
        pos = nil
      end
      super(message, original)
      @issue_code = issue_code
      @file = file unless (file.is_a?(String) && file.empty?)
      self.line = line if line
      self.pos = pos if pos
    end

    def line=(line)
      line = line.to_i if line
      @line = line
    end

    def pos=(pos)
      pos = pos.to_i if pos
      @pos = pos
    end
  end

  class ParseError < Puppet::Error
    include ExternalFileError
  end

  class ResourceError < Puppet::Error
    include ExternalFileError
  end

  # An error that already contains location information in the message text
  class PreformattedError < Puppet::ParseError
  end

  # An error class for when I don't know what happened.  Automatically
  # prints a stack trace when in debug mode.
  class DevError < Puppet::Error
    include ExternalFileError
  end
end
