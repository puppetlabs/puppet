require 'semantic'

module Semantic

  # @note Semantic::Version subclasses Numeric so that it has sane Range
  #       semantics in Ruby 1.9+.
  class Version < Numeric
    include Comparable

    class ValidationFailure < ArgumentError; end

    class << self
      LOOSE_REGEX = /
        \A
        (\d+)[.](\d+)[.](\d+) # Major . Minor . Patch
        (?: [-](.*?))?        # Prerelease
        (?: [+](.*?))?        # Build
        \Z
      /x

      # Parse a Semantic Version string.
      #
      # @param ver [String] the version string to parse
      # @return [Version] a comparable {Version} object
      def parse(ver)
        match, major, minor, patch, prerelease, build = *ver.match(LOOSE_REGEX)

        if match.nil?
          raise 'Version numbers MUST begin with three dot-separated numbers'
        elsif [major, minor, patch].any? { |x| x =~ /^0\d+/ }
          raise 'Version numbers MUST NOT contain leading zeroes'
        end

        prerelease = parse_prerelease(prerelease) if prerelease
        build = parse_build_metadata(build) if build

        self.new(major.to_i, minor.to_i, patch.to_i, prerelease, build)
      end

      private
      def parse_prerelease(prerelease)
        subject = 'Prerelease identifiers'
        prerelease = prerelease.split('.', -1)

        if prerelease.empty? or prerelease.any? { |x| x.empty? }
          raise "#{subject} MUST NOT be empty"
        elsif prerelease.any? { |x| x =~ /[^0-9a-zA-Z-]/ }
          raise "#{subject} MUST use only ASCII alphanumerics and hyphens"
        elsif prerelease.any? { |x| x =~ /^0\d+$/ }
          raise "#{subject} MUST NOT contain leading zeroes"
        end

        return prerelease.map { |x| x =~ /^\d+$/ ? x.to_i : x }
      end

      def parse_build_metadata(build)
        subject = 'Build identifiers'
        build = build.split('.', -1)

        if build.empty? or build.any? { |x| x.empty? }
          raise "#{subject} MUST NOT be empty"
        elsif build.any? { |x| x =~ /[^0-9a-zA-Z-]/ }
          raise "#{subject} MUST use only ASCII alphanumerics and hyphens"
        end

        return build
      end

      def raise(msg)
        super ValidationFailure, msg, caller.drop_while { |x| x !~ /\bparse\b/ }
      end
    end

    attr_reader :major, :minor, :patch

    def initialize(major, minor, patch, prerelease = nil, build = nil)
      @major      = major
      @minor      = minor
      @patch      = patch
      @prerelease = prerelease
      @build      = build
    end

    def next(part)
      case part
      when :major
        self.class.new(@major.next, 0, 0)
      when :minor
        self.class.new(@major, @minor.next, 0)
      when :patch
        self.class.new(@major, @minor, @patch.next)
      end
    end

    def prerelease
      @prerelease && @prerelease.join('.')
    end

    # @return [Boolean] true if this is a stable release
    def stable?
      @prerelease.nil?
    end

    def build
      @build && @build.join('.')
    end

    def <=>(other)
      return self.major <=> other.major unless self.major == other.major
      return self.minor <=> other.minor unless self.minor == other.minor
      return self.patch <=> other.patch unless self.patch == other.patch
      return compare_prerelease(other)
    end

    def to_s
      "#{major}.#{minor}.#{patch}" +
      (@prerelease.nil? || prerelease.empty? ? '' : "-" + prerelease) +
      (@build.nil?      || build.empty?      ? '' : "+" + build     )
    end

    def hash
      self.to_s.hash
    end

    private
    # This is a hack; tildes sort later than any valid identifier. The
    # advantage is that we don't need to handle stable vs. prerelease
    # comparisons separately.
    @@STABLE_RELEASE = [ '~' ].freeze

    def compare_prerelease(other)
      all_mine  = @prerelease                               || @@STABLE_RELEASE
      all_yours = other.instance_variable_get(:@prerelease) || @@STABLE_RELEASE

      # Precedence is determined by comparing each dot separated identifier from
      # left to right...
      size = [ all_mine.size, all_yours.size ].max
      Array.new(size).zip(all_mine, all_yours) do |_, mine, yours|

        # ...until a difference is found.
        next if mine == yours

        # Numbers are compared numerically, strings are compared ASCIIbetically.
        if mine.class == yours.class
          return mine <=> yours

        # A larger set of pre-release fields has a higher precedence.
        elsif mine.nil?
          return -1
        elsif yours.nil?
          return 1

        # Numeric identifiers always have lower precedence than non-numeric.
        elsif mine.is_a? Numeric
          return -1
        elsif yours.is_a? Numeric
          return 1
        end
      end

      return 0
    end

    def first_prerelease
      self.class.new(@major, @minor, @patch, [])
    end
  end
end
