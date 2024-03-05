# frozen_string_literal: true

require 'pathname'
require_relative '../../puppet/error'

module Puppet::FileSystem
  class PathPattern
    class InvalidPattern < Puppet::Error; end

    DOTDOT = '..'
    ABSOLUTE_UNIX = %r{^/}
    ABSOLUTE_WINDOWS = /^[a-z]:/i
    CURRENT_DRIVE_RELATIVE_WINDOWS = /^\\/

    def self.relative(pattern)
      RelativePathPattern.new(pattern)
    end

    def self.absolute(pattern)
      AbsolutePathPattern.new(pattern)
    end

    class << self
      protected :new
    end

    # @param prefix [AbsolutePathPattern] An absolute path pattern instance
    # @return [AbsolutePathPattern] A new AbsolutePathPattern prepended with
    #   the passed prefix's pattern.
    def prefix_with(prefix)
      new_pathname = prefix.pathname + pathname
      self.class.absolute(new_pathname.to_s)
    end

    def glob
      Dir.glob(@pathstr)
    end

    def to_s
      @pathstr
    end

    protected

    attr_reader :pathname

    private

    def validate
      if @pathstr.split(Pathname::SEPARATOR_PAT).any? { |f| f == DOTDOT }
        raise(InvalidPattern, _("PathPatterns cannot be created with directory traversals."))
      elsif @pathstr.match?(CURRENT_DRIVE_RELATIVE_WINDOWS)
        raise(InvalidPattern, _("A PathPattern cannot be a Windows current drive relative path."))
      end
    end

    def initialize(pattern)
      begin
        @pathname = Pathname.new(pattern.strip)
        @pathstr = @pathname.to_s
      rescue ArgumentError => error
        raise InvalidPattern.new(_("PathPatterns cannot be created with a zero byte."), error)
      end
      validate
    end
  end

  class RelativePathPattern < PathPattern
    def absolute?
      false
    end

    def validate
      super
      if @pathstr.match?(ABSOLUTE_WINDOWS)
        raise(InvalidPattern, _("A relative PathPattern cannot be prefixed with a drive."))
      elsif @pathstr.match?(ABSOLUTE_UNIX)
        raise(InvalidPattern, _("A relative PathPattern cannot be an absolute path."))
      end
    end
  end

  class AbsolutePathPattern < PathPattern
    def absolute?
      true
    end

    def validate
      super
      if !@pathstr.match?(ABSOLUTE_UNIX) && !@pathstr.match?(ABSOLUTE_WINDOWS)
        raise(InvalidPattern, _("An absolute PathPattern cannot be a relative path."))
      end
    end
  end
end
