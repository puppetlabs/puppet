# frozen_string_literal: true

module Puppet
  # The base class for all Puppet errors. It can wrap another exception
  class Error < RuntimeError
    attr_accessor :original

    def initialize(message, original = nil)
      super(message.scrub)
      @original = original
    end
  end

  module ExternalFileError
    # This module implements logging with a filename and line number. Use this
    # for errors that need to report a location in a non-ruby file that we
    # parse.
    attr_accessor :line, :file, :pos, :puppetstack

    # May be called with 3 arguments for message, file, line, and exception, or
    # 4 args including the position on the line.
    #
    def initialize(message, file = nil, line = nil, pos = nil, original = nil)
      if pos.is_a? Exception
        original = pos
        pos = nil
      end

      super(message, original)

      @file = file unless file.is_a?(String) && file.empty?
      @line = line
      @pos = pos

      if original && original.respond_to?(:puppetstack)
        @puppetstack = original.puppetstack
      else
        @puppetstack = Puppet::Pops::PuppetStack.stacktrace()
      end
    end

    def to_s
      msg = super
      @file = nil if @file.is_a?(String) && @file.empty?
      msg += Puppet::Util::Errors.error_location_with_space(@file, @line, @pos)
      msg
    end
  end

  class ParseError < Puppet::Error
    include ExternalFileError
  end

  class ResourceError < Puppet::Error
    include ExternalFileError
  end

  # Contains an issue code and can be annotated with an environment and a node
  class ParseErrorWithIssue < Puppet::ParseError
    attr_reader :issue_code, :basic_message, :arguments
    attr_accessor :environment, :node

    # @param message [String] The error message
    # @param file [String] The path to the file where the error was found
    # @param line [Integer] The line in the file
    # @param pos [Integer] The position on the line
    # @param original [Exception] Original exception
    # @param issue_code [Symbol] The issue code
    # @param arguments [Hash{Symbol=>Object}] Issue arguments
    #
    def initialize(message, file = nil, line = nil, pos = nil, original = nil, issue_code = nil, arguments = nil)
      super(message, file, line, pos, original)
      @issue_code = issue_code
      @basic_message = message
      @arguments = arguments
    end

    def to_s
      msg = super
      msg = _("Could not parse for environment %{environment}: %{message}") % { environment: environment, message: msg } if environment
      msg = _("%{message} on node %{node}") % { message: msg, node: node } if node
      msg
    end

    def to_h
      {
        :issue_code => issue_code,
        :message => basic_message,
        :full_message => to_s,
        :file => file,
        :line => line,
        :pos => pos,
        :environment => environment.to_s,
        :node => node.to_s,
      }
    end

    def self.from_issue_and_stack(issue, args = {})
      filename, line = Puppet::Pops::PuppetStack.top_of_stack

      self.new(
        issue.format(args),
        filename,
        line,
        nil,
        nil,
        issue.issue_code,
        args
      )
    end
  end

  # An error that already contains location information in the message text
  class PreformattedError < Puppet::ParseErrorWithIssue
  end

  # An error class for when I don't know what happened.  Automatically
  # prints a stack trace when in debug mode.
  class DevError < Puppet::Error
    include ExternalFileError
  end

  class MissingCommand < Puppet::Error
  end

  # Raised when we failed to acquire a lock
  class LockError < Puppet::Error
  end

  # An Error suitable for raising an error with details in a Puppet::Datatypes::Error
  # that can be used as a value in the Puppet Language
  #
  class ErrorWithData < Puppet::Error
    include ExternalFileError
    attr_reader :error_data

    def initialize(error_data, message, file: nil, line: nil, pos: nil, original: nil)
      super(message, file, line, pos, original)
      @error_data = error_data
    end
  end
end
