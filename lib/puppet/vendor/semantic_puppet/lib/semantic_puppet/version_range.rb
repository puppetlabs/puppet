require 'semantic_puppet'

module SemanticPuppet
  # A Semantic Version Range.
  #
  # @see https://github.com/npm/node-semver for full specification
  # @api public
  class VersionRange
    UPPER_X = 'X'.freeze
    LOWER_X = 'x'.freeze
    STAR = '*'.freeze

    NR = '0|[1-9][0-9]*'.freeze
    XR = '(x|X|\*|' + NR + ')'.freeze
    XR_NC = '(?:x|X|\*|' + NR + ')'.freeze

    PART = '(?:[0-9A-Za-z-]+)'.freeze
    PARTS = PART + '(?:\.' + PART + ')*'.freeze
    QUALIFIER = '(?:-(' + PARTS + '))?(?:\+(' + PARTS + '))?'.freeze
    QUALIFIER_NC = '(?:-' + PARTS + ')?(?:\+' + PARTS + ')?'.freeze

    PARTIAL = XR_NC + '(?:\.' + XR_NC + '(?:\.' + XR_NC + QUALIFIER_NC + ')?)?'.freeze

    # The ~> isn't in the spec but allowed
    SIMPLE = '([<>=~^]|<=|>=|~>|~=)?(' + PARTIAL + ')'.freeze
    SIMPLE_EXPR = /\A#{SIMPLE}\z/.freeze

    SIMPLE_WITH_EXTRA_WS = '([<>=~^]|<=|>=)?\s+(' + PARTIAL + ')'.freeze
    SIMPLE_WITH_EXTRA_WS_EXPR = /\A#{SIMPLE_WITH_EXTRA_WS}\z/.freeze

    HYPHEN = '(' + PARTIAL + ')\s+-\s+(' + PARTIAL + ')'.freeze
    HYPHEN_EXPR = /\A#{HYPHEN}\z/.freeze

    PARTIAL_EXPR = /\A#{XR}(?:\.#{XR}(?:\.#{XR}#{QUALIFIER})?)?\z/.freeze

    LOGICAL_OR = /\s*\|\|\s*/.freeze
    RANGE_SPLIT = /\s+/.freeze

    # Parses a version range string into a comparable {VersionRange} instance.
    #
    # Currently parsed version range string may take any of the following:
    # forms:
    #
    # * Regular Semantic Version strings
    #   * ex. `"1.0.0"`, `"1.2.3-pre"`
    # * Partial Semantic Version strings
    #   * ex. `"1.0.x"`, `"1"`, `"2.X"`, `"3.*"`,
    # * Inequalities
    #   * ex. `"> 1.0.0"`, `"<3.2.0"`, `">=4.0.0"`
    # * Approximate Caret Versions
    #   * ex. `"^1"`, `"^3.2"`, `"^4.1.0"`
    # * Approximate Tilde Versions
    #   * ex. `"~1.0.0"`, `"~ 3.2.0"`, `"~4.0.0"`
    # * Inclusive Ranges
    #   * ex. `"1.0.0 - 1.3.9"`
    # * Range Intersections
    #   * ex. `">1.0.0 <=2.3.0"`
    # * Combined ranges
    #   * ex, `">=1.0.0 <2.3.0 || >=2.5.0 <3.0.0"`
    #
    # @param range_string [String] the version range string to parse
    # @return [VersionRange] a new {VersionRange} instance
    # @api public
    def self.parse(range_string)
      # Remove extra whitespace after operators. Such whitespace should not cause a split
      range_set = range_string.gsub(/([><=~^])(?:\s+|\s*v)/, '\1')
      ranges = range_set.split(LOGICAL_OR)
      return ALL_RANGE if ranges.empty?

      new(ranges.map do |range|
        if range =~ HYPHEN_EXPR
          MinMaxRange.create(GtEqRange.new(parse_version($1)), LtEqRange.new(parse_version($2)))
        else
          # Split on whitespace
          simples = range.split(RANGE_SPLIT).map do |simple|
            match_data = SIMPLE_EXPR.match(simple)
            raise ArgumentError, _("Unparsable version range: \"%{range}\"") % { range: range_string } unless match_data
            operand = match_data[2]

            # Case based on operator
            case match_data[1]
            when '~', '~>', '~='
              parse_tilde(operand)
            when '^'
              parse_caret(operand)
            when '>'
              parse_gt_version(operand)
            when '>='
              GtEqRange.new(parse_version(operand))
            when '<'
              LtRange.new(parse_version(operand))
            when '<='
              parse_lteq_version(operand)
            when '='
              parse_xrange(operand)
            else
              parse_xrange(operand)
            end
          end
          simples.size == 1 ? simples[0] : MinMaxRange.create(*simples)
        end
      end.uniq, range_string).freeze
    end

    def self.parse_partial(expr)
      match_data = PARTIAL_EXPR.match(expr)
      raise ArgumentError, _("Unparsable version range: \"%{expr}\"") % { expr: expr } unless match_data
      match_data
    end
    private_class_method :parse_partial

    def self.parse_caret(expr)
      match_data = parse_partial(expr)
      major = digit(match_data[1])
      major == 0 ? allow_patch_updates(major, match_data) : allow_minor_updates(major, match_data)
    end
    private_class_method :parse_caret

    def self.parse_tilde(expr)
      match_data = parse_partial(expr)
      allow_patch_updates(digit(match_data[1]), match_data)
    end
    private_class_method :parse_tilde

    def self.parse_xrange(expr)
      match_data = parse_partial(expr)
      allow_patch_updates(digit(match_data[1]), match_data, false)
    end
    private_class_method :parse_xrange

    def self.allow_patch_updates(major, match_data, tilde_or_caret = true)
      return AllRange::SINGLETON unless major

      minor = digit(match_data[2])
      return MinMaxRange.new(GtEqRange.new(Version.new(major, 0, 0)), LtRange.new(Version.new(major + 1, 0, 0))) unless minor

      patch = digit(match_data[3])
      return MinMaxRange.new(GtEqRange.new(Version.new(major, minor, 0)), LtRange.new(Version.new(major, minor + 1, 0))) unless patch

      version = Version.new(major, minor, patch, Version.parse_prerelease(match_data[4]), Version.parse_build(match_data[5]))
      return EqRange.new(version) unless tilde_or_caret

      MinMaxRange.new(GtEqRange.new(version), LtRange.new(Version.new(major, minor + 1, 0)))
    end
    private_class_method :allow_patch_updates

    def self.allow_minor_updates(major, match_data)
      return AllRange.SINGLETON unless major
      minor = digit(match_data[2])
      if minor
        patch = digit(match_data[3])
        if patch.nil?
          MinMaxRange.new(GtEqRange.new(Version.new(major, minor, 0)), LtRange.new(Version.new(major + 1, 0, 0)))
        else
          if match_data[4].nil?
            MinMaxRange.new(GtEqRange.new(Version.new(major, minor, patch)), LtRange.new(Version.new(major + 1, 0, 0)))
          else
            MinMaxRange.new(
              GtEqRange.new(
                Version.new(major, minor, patch, Version.parse_prerelease(match_data[4]), Version.parse_build(match_data[5]))),
              LtRange.new(Version.new(major + 1, 0, 0)))
          end
        end
      else
        MinMaxRange.new(GtEqRange.new(Version.new(major, 0, 0)), LtRange.new(Version.new(major + 1, 0, 0)))
      end
    end
    private_class_method :allow_minor_updates

    def self.digit(str)
      (str.nil? || UPPER_X == str || LOWER_X == str || STAR == str) ? nil : str.to_i
    end
    private_class_method :digit

    def self.parse_version(expr)
      match_data = parse_partial(expr)
      major = digit(match_data[1]) || 0
      minor = digit(match_data[2]) || 0
      patch = digit(match_data[3]) || 0
      Version.new(major, minor, patch, Version.parse_prerelease(match_data[4]), Version.parse_build(match_data[5]))
    end
    private_class_method :parse_version

    def self.parse_gt_version(expr)
      match_data = parse_partial(expr)
      major = digit(match_data[1])
      return LtRange::MATCH_NOTHING unless major
      minor = digit(match_data[2])
      return GtEqRange.new(Version.new(major + 1, 0, 0)) unless minor
      patch = digit(match_data[3])
      return GtEqRange.new(Version.new(major, minor + 1, 0)) unless patch
      return GtRange.new(Version.new(major, minor, patch, Version.parse_prerelease(match_data[4]), Version.parse_build(match_data[5])))
    end
    private_class_method :parse_gt_version

    def self.parse_lteq_version(expr)
      match_data = parse_partial(expr)
      major = digit(match_data[1])
      return AllRange.SINGLETON unless major
      minor = digit(match_data[2])
      return LtRange.new(Version.new(major + 1, 0, 0)) unless minor
      patch = digit(match_data[3])
      return LtRange.new(Version.new(major, minor + 1, 0)) unless patch
      return LtEqRange.new(Version.new(major, minor, patch, Version.parse_prerelease(match_data[4]), Version.parse_build(match_data[5])))
    end
    private_class_method :parse_lteq_version

    # Provides read access to the ranges. For internal use only
    # @api private
    attr_reader :ranges

    # Creates a new version range
    # @overload initialize(from, to, exclude_end = false)
    #   Creates a new instance using ruby `Range` semantics
    #   @param begin [String,Version] the version denoting the start of the range (always inclusive)
    #   @param end [String,Version] the version denoting the end of the range
    #   @param exclude_end [Boolean] `true` if the `end` version should be excluded from the range
    # @overload initialize(ranges, string)
    #   Creates a new instance based on parsed content. For internal use only
    #   @param ranges [Array<AbstractRange>] the ranges to include in this range
    #   @param string [String] the original string representation that was parsed to produce the ranges
    #
    # @api private
    def initialize(ranges, string, exclude_end = nil)
      unless ranges.is_a?(Array)
        lb = GtEqRange.new(ranges)
        if exclude_end
          ub = LtRange.new(string)
          string = ">=#{string} <#{ranges}"
        else
          ub = LtEqRange.new(string)
          string = "#{string} - #{ranges}"
        end
        ranges = [MinMaxRange.create(lb, ub)]
      end
      ranges.compact!

      merge_happened = true
      while ranges.size > 1 && merge_happened
        # merge ranges if possible
        merge_happened = false
        result = []
        until ranges.empty?
          unmerged = []
          x = ranges.pop
          result << ranges.reduce(x) do |memo, y|
            merged = memo.merge(y)
            if merged.nil?
              unmerged << y
            else
              merge_happened = true
              memo = merged
            end
            memo
          end
          ranges = unmerged
        end
        ranges = result.reverse!
      end

      ranges = [LtRange::MATCH_NOTHING] if ranges.empty?
      @ranges = ranges
      @string = string.nil? ? ranges.join(' || ') : string
    end

    def eql?(range)
      range.is_a?(VersionRange) && @ranges.eql?(range.ranges)
    end
    alias == eql?

    def hash
      @ranges.hash
    end

    # Returns the version that denotes the beginning of this range.
    #
    # Since this really is an OR between disparate ranges, it may have multiple beginnings. This method
    # returns `nil` if that is the case.
    #
    # @return [Version] the beginning of the range, or `nil` if there are multiple beginnings
    # @api public
    def begin
      @ranges.size == 1 ? @ranges[0].begin : nil
    end

    # Returns the version that denotes the end of this range.
    #
    # Since this really is an OR between disparate ranges, it may have multiple ends. This method
    # returns `nil` if that is the case.
    #
    # @return [Version] the end of the range, or `nil` if there are multiple ends
    # @api public
    def end
      @ranges.size == 1 ? @ranges[0].end : nil
    end

    # Returns `true` if the beginning is excluded from the range.
    #
    # Since this really is an OR between disparate ranges, it may have multiple beginnings. This method
    # returns `nil` if that is the case.
    #
    # @return [Boolean] `true` if the beginning is excluded from the range, `false` if included, or `nil` if there are multiple beginnings
    # @api public
    def exclude_begin?
      @ranges.size == 1 ? @ranges[0].exclude_begin? : nil
    end

    # Returns `true` if the end is excluded from the range.
    #
    # Since this really is an OR between disparate ranges, it may have multiple ends. This method
    # returns `nil` if that is the case.
    #
    # @return [Boolean] `true` if the end is excluded from the range, `false` if not, or `nil` if there are multiple ends
    # @api public
    def exclude_end?
      @ranges.size == 1 ? @ranges[0].exclude_end? : nil
    end

    # @return [Boolean] `true` if the given version is included in the range
    # @api public
    def include?(version)
      @ranges.any? { |range| range.include?(version) && (version.stable? || range.test_prerelease?(version)) }
    end
    alias member? include?
    alias cover? include?
    alias === include?

    # Computes the intersection of a pair of ranges. If the ranges have no
    # useful intersection, an empty range is returned.
    #
    # @param other [VersionRange] the range to intersect with
    # @return [VersionRange] the common subset
    # @api public
    def intersection(other)
      raise ArgumentError, _("value must be a %{type}") % { :type => self.class.name } unless other.is_a?(VersionRange)
      result = @ranges.map { |range| other.ranges.map { |o_range| range.intersection(o_range) } }.flatten
      result.compact!
      result.uniq!
      result.empty? ? EMPTY_RANGE : VersionRange.new(result, nil)
    end
    alias :& :intersection

    # Returns a string representation of this range. This will be the string that was used
    # when the range was parsed.
    #
    # @return [String] a range expression representing this VersionRange
    # @api public
    def to_s
      @string
    end

    # Returns a canonical string representation of this range, assembled from the internal
    # matchers.
    #
    # @return [String] a range expression representing this VersionRange
    # @api public
    def inspect
      @ranges.join(' || ')
    end

    # @api private
    class AbstractRange
      def include?(_)
        true
      end

      def begin
        Version::MIN
      end

      def end
        Version::MAX
      end

      def exclude_begin?
        false
      end

      def exclude_end?
        false
      end

      def eql?(other)
        other.class.eql?(self.class)
      end

      def ==(other)
        eql?(other)
      end

      def lower_bound?
        false
      end

      def upper_bound?
        false
      end

      # Merge two ranges so that the result matches the intersection of all matching versions.
      #
      # @param range [AbstractRange] the range to intersect with
      # @return [AbstractRange,nil] the intersection between the ranges
      #
      # @api private
      def intersection(range)
        cmp = self.begin <=> range.end
        if cmp > 0
          nil
        elsif cmp == 0
          exclude_begin? || range.exclude_end? ? nil : EqRange.new(self.begin)
        else
          cmp = range.begin <=> self.end
          if cmp > 0
            nil
          elsif cmp == 0
            range.exclude_begin? || exclude_end? ? nil : EqRange.new(range.begin)
          else
            cmp = self.begin <=> range.begin
            min = if cmp < 0
              range
            elsif cmp > 0
              self
            else
              self.exclude_begin? ? self : range
            end

            cmp = self.end <=> range.end
            max = if cmp > 0
              range
            elsif cmp < 0
              self
            else
              self.exclude_end? ? self : range
            end

            if !max.upper_bound?
              min
            elsif !min.lower_bound?
              max
            else
              MinMaxRange.new(min, max)
            end
          end
        end
      end

      # Merge two ranges so that the result matches the sum of all matching versions. A merge
      # is only possible when the ranges are either adjacent or have an overlap.
      #
      # @param other [AbstractRange] the range to merge with
      # @return [AbstractRange,nil] the result of the merge
      #
      # @api private
      def merge(other)
        if include?(other.begin) || other.include?(self.begin)
          cmp = self.begin <=> other.begin
          if cmp < 0
            min = self.begin
            excl_begin = exclude_begin?
          elsif cmp > 0
            min = other.begin
            excl_begin = other.exclude_begin?
          else
            min = self.begin
            excl_begin = exclude_begin? && other.exclude_begin?
          end

          cmp = self.end <=> other.end
          if cmp > 0
            max = self.end
            excl_end = self.exclude_end?
          elsif cmp < 0
            max = other.end
            excl_end = other.exclude_end?
          else
            max = self.end
            excl_end = exclude_end && other.exclude_end?
          end

          MinMaxRange.create(excl_begin ? GtRange.new(min) : GtEqRange.new(min), excl_end ? LtRange.new(max) : LtEqRange.new(max))
        elsif exclude_end? && !other.exclude_begin? && self.end == other.begin
          # Adjacent, self before other
          from_to(self, other)
        elsif other.exclude_end? && !exclude_begin? && other.end == self.begin
          # Adjacent, other before self
          from_to(other, self)
        elsif !exclude_end? && !other.exclude_begin? && self.end.next(:patch) == other.begin
          # Adjacent, self before other
          from_to(self, other)
        elsif !other.exclude_end? && !exclude_begin? && other.end.next(:patch) == self.begin
          # Adjacent, other before self
          from_to(other, self)
        else
          # No overlap
          nil
        end
      end

      # Checks if this matcher accepts a prerelease with the same major, minor, patch triple as the given version. Only matchers
      # where this has been explicitly stated will respond `true` to this method
      #
      # @return [Boolean] `true` if this matcher accepts a prerelease with the tuple from the given version
      def test_prerelease?(_)
        false
      end

      private

      def from_to(a, b)
        MinMaxRange.create(a.exclude_begin? ? GtRange.new(a.begin) : GtEqRange.new(a.begin), b.exclude_end? ? LtRange.new(b.end) : LtEqRange.new(b.end))
      end
    end

    # @api private
    class AllRange < AbstractRange
      SINGLETON = AllRange.new

      def intersection(range)
        range
      end

      def merge(range)
        self
      end

      def test_prerelease?(_)
        true
      end

      def to_s
        '*'
      end
    end

    # @api private
    class MinMaxRange < AbstractRange
      attr_reader :min, :max

      def self.create(*ranges)
        ranges.reduce { |memo, range| memo.intersection(range) }
      end

      def initialize(min, max)
        @min = min.is_a?(MinMaxRange) ? min.min : min
        @max = max.is_a?(MinMaxRange) ? max.max : max
      end

      def begin
        @min.begin
      end

      def end
        @max.end
      end

      def exclude_begin?
        @min.exclude_begin?
      end

      def exclude_end?
        @max.exclude_end?
      end

      def eql?(other)
        super && @min.eql?(other.min) && @max.eql?(other.max)
      end

      def hash
        @min.hash ^ @max.hash
      end

      def include?(version)
        @min.include?(version) && @max.include?(version)
      end

      def lower_bound?
        @min.lower_bound?
      end

      def upper_bound?
        @max.upper_bound?
      end

      def test_prerelease?(version)
        @min.test_prerelease?(version) || @max.test_prerelease?(version)
      end


      def to_s
        "#{@min} #{@max}"
      end
      alias inspect to_s
    end

    # @api private
    class ComparatorRange < AbstractRange
      attr_reader :version

      def initialize(version)
        @version = version
      end

      def eql?(other)
        super && @version.eql?(other.version)
      end

      def hash
        @class.hash ^ @version.hash
      end

      # Checks if this matcher accepts a prerelease with the same major, minor, patch triple as the given version
      def test_prerelease?(version)
        !@version.stable? && @version.major == version.major && @version.minor == version.minor && @version.patch == version.patch
      end
    end

    # @api private
    class GtRange < ComparatorRange
      def include?(version)
        version > @version
      end

      def exclude_begin?
        true
      end

      def begin
        @version
      end

      def lower_bound?
        true
      end

      def to_s
        ">#{@version}"
      end
    end

    # @api private
    class GtEqRange < ComparatorRange
      def include?(version)
        version >= @version
      end

      def begin
        @version
      end

      def lower_bound?
        @version != Version::MIN
      end

      def to_s
        ">=#{@version}"
      end
    end

    # @api private
    class LtRange < ComparatorRange
      MATCH_NOTHING = LtRange.new(Version::MIN)

      def include?(version)
        version < @version
      end

      def exclude_end?
        true
      end

      def end
        @version
      end

      def upper_bound?
        true
      end

      def to_s
        self.equal?(MATCH_NOTHING) ? '<0.0.0' : "<#{@version}"
      end
    end

    # @api private
    class LtEqRange < ComparatorRange
      def include?(version)
        version <= @version
      end

      def end
        @version
      end

      def upper_bound?
        @version != Version::MAX
      end

      def to_s
        "<=#{@version}"
      end
    end

    # @api private
    class EqRange < ComparatorRange
      def include?(version)
        version == @version
      end

      def begin
        @version
      end

      def lower_bound?
        @version != Version::MIN
      end

      def upper_bound?
        @version != Version::MAX
      end

      def end
        @version
      end

      def to_s
        @version.to_s
      end
    end

    # A range that matches no versions
    EMPTY_RANGE = VersionRange.new([], nil).freeze
    ALL_RANGE = VersionRange.new([AllRange::SINGLETON], '*')
  end
end
