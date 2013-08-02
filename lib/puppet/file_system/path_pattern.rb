require 'pathname'

module Puppet::FileSystem
  class PathPattern
    class InvalidPattern < Puppet::Error; end

    TRAVERSAL = /\.\./
    ABSOLUTE_UNIX = /^\//
    ABSOLUTE_WINDOWS = /^[a-z]:/i
    #ABSOLUT_VODKA #notappearinginthisclass
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
      Dir.glob(pathname.to_s)
    end

    def to_s
      pathname.to_s
    end

    protected

    attr_reader :pathname

    private

    def validate(pattern)
      stripped = pattern.strip
      case stripped
      when TRAVERSAL
        raise(InvalidPattern, "PathPatterns cannot be created with directory traversals.")
      when CURRENT_DRIVE_RELATIVE_WINDOWS
        raise(InvalidPattern, "A PathPattern cannot be a Windows current drive relative path.")
      end
      return stripped
    end

    def initialize(pattern)
      stripped = validate(pattern)
      begin
        @pathname = Pathname.new(stripped)
      rescue ArgumentError => error
        raise InvalidPattern.new("PathPatterns cannot be created with a zero byte.", error)
      end
    end
  end

  class RelativePathPattern < PathPattern
    def absolute?
      false
    end

    def validate(pattern)
      stripped = super(pattern)
      case stripped
      when ABSOLUTE_WINDOWS
        raise(InvalidPattern, "A relative PathPattern cannot be prefixed with a drive.")
      when ABSOLUTE_UNIX
        raise(InvalidPattern, "A relative PathPattern cannot be an absolute path.")
      end
      return stripped
    end
  end

  class AbsolutePathPattern < PathPattern
    def absolute?
      true
    end

    def validate(pattern)
      stripped = super(pattern)
      if stripped !~ ABSOLUTE_UNIX and stripped !~ ABSOLUTE_WINDOWS
        raise(InvalidPattern, "An absolute PathPattern cannot be a relative path.")
      end
      stripped
    end
  end
end
