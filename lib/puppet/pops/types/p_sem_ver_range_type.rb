module Puppet::Pops
module Types

# An unparameterized type that represents all VersionRange instances
#
# @api public
class PSemVerRangeType < PScalarType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarType')
  end

  # Check if a version is included in a version range. The version can be a string or
  # a `Semantic::SemVer`
  #
  # @param range [Semantic::VersionRange] the range to match against
  # @param version [Semantic::Version,String] the version to match
  # @return [Boolean] `true` if the range includes the given version
  #
  # @api public
  def self.include?(range, version)
    case version
    when Semantic::Version
      range.include?(version)
    when String
      begin
        range.include?(Semantic::Version.parse(version))
      rescue Semantic::Version::ValidationFailure
        false
      end
    else
      false
    end
  end

  # Creates a {Semantic::VersionRange} from the given _version_range_ argument. If the argument is `nil` or
  # a {Semantic::VersionRange}, it is returned. If it is a {String}, it will be parsed into a
  # {Semantic::VersionRange}. Any other class will raise an {ArgumentError}.
  #
  # @param version_range [Semantic::VersionRange,String,nil] the version range to convert
  # @return [Semantic::VersionRange] the converted version range
  # @raise [ArgumentError] when the argument cannot be converted into a version range
  #
  def self.convert(version_range)
    case version_range
    when nil, Semantic::VersionRange
      version_range
    when String
      Semantic::VersionRange.parse(version_range)
    else
      raise ArgumentError, "Unable to convert a #{version_range.class.name} to a SemVerRange"
    end
  end

  # Checks if range _a_ is a sub-range of (i.e. completely covered by) range _b_
  # @param a [Semantic::VersionRange] the first range
  # @param b [Semantic::VersionRange] the second range
  #
  # @return [Boolean] `true` if _a_ is completely covered by _b_
  def self.covered_by?(a, b)
    b.begin <= a.begin && (b.end > a.end || b.end == a.end && (!b.exclude_end? || a.exclude_end?))
  end

  # Merge two ranges so that the result matches all versions matched by both. A merge
  # is only possible when the ranges are either adjacent or have an overlap.
  #
  # @param a [Semantic::VersionRange] the first range
  # @param b [Semantic::VersionRange] the second range
  # @return [Semantic::VersionRange,nil] the result of the merge
  #
  # @api public
  def self.merge(a, b)
    if a.include?(b.begin) || b.include?(a.begin)
      max = [a.end, b.end].max
      exclude_end = false
      if a.exclude_end?
        exclude_end = max == a.end && (max > b.end || b.exclude_end?)
      elsif b.exclude_end?
        exclude_end = max == b.end && (max > a.end || a.exclude_end?)
      end
      Semantic::VersionRange.new([a.begin, b.begin].min, max, exclude_end)
    elsif a.exclude_end? && a.end == b.begin
      # Adjacent, a before b
      Semantic::VersionRange.new(a.begin, b.end, b.exclude_end?)
    elsif b.exclude_end? && b.end == a.begin
      # Adjacent, b before a
      Semantic::VersionRange.new(b.begin, a.end, a.exclude_end?)
    else
      # No overlap
      nil
    end
  end

  def instance?(o, guard = nil)
    o.is_a?(Semantic::VersionRange)
  end

  def eql?(o)
    self.class == o.class
  end

  def hash?
    super ^ @version_range.hash
  end

  def self.new_function(_, loader)
    range_expr = "\\A#{range_pattern}\\Z"
    @@new_function ||= Puppet::Functions.create_loaded_function(:new_VersionRange, loader) do
      local_types do
        type 'SemVerRangeString = String[1]'
        type 'SemVerRangeHash = Struct[{min=>Variant[default,SemVer],Optional[max]=>Variant[default,SemVer],Optional[exclude_max]=>Boolean}]'
      end

      # Constructs a VersionRange from a String with a format specified by
      #
      # https://github.com/npm/node-semver#range-grammar
      #
      # The logical or || operator is not implemented since it effectively builds
      # an array of ranges that may be disparate. The {{Semantic::VersionRange}} inherits
      # from the standard ruby range. It must be possible to describe that range in terms
      # of min, max, and exclude max.
      #
      # The Puppet Version type is parameterized and accepts multiple ranges so creating such
      # constraints is still possible. It will just require several parameters rather than one
      # parameter containing the '||' operator.
      #
      dispatch :from_string do
        param 'SemVerRangeString', :str
      end

      # Constructs a VersionRange from a min, and a max version. The Boolean argument denotes
      # whether or not the max version is excluded or included in the range. It is included by
      # default.
      #
      dispatch :from_versions do
        param 'Variant[default,SemVer]', :min
        param 'Variant[default,SemVer]', :max
        optional_param 'Boolean', :exclude_max
      end

      # Same as #from_versions but each argument is instead given in a Hash
      #
      dispatch :from_hash do
        param 'SemVerRangeHash', :hash_args
      end

      def from_string(str)
        Semantic::VersionRange.parse(str)
      end

      def from_versions(min, max = :default, exclude_max = false)
        min = Semantic::Version::MIN if min == :default
        max = Semantic::Version::MAX if max == :default
        Semantic::VersionRange.new(min, max, exclude_max)
      end

      def from_hash(hash)
        from_versions(hash['min'], hash.fetch('max') { :default }, hash.fetch('exclude_max') { false })
      end
    end
  end

  DEFAULT = PSemVerRangeType.new

  protected

  def _assignable?(o, guard)
    self == o
  end

  def self.range_pattern
    part = '(?<part>[0-9A-Za-z-]+)'
    parts = "(?<parts>#{part}(?:\\.\\g<part>)*)"

    qualifier = "(?:-#{parts})?(?:\\+\\g<parts>)?"

    xr = '(?<xr>[xX*]|0|[1-9][0-9]*)'
    partial = "(?<partial>#{xr}(?:\\.\\g<xr>(?:\\.\\g<xr>#{qualifier})?)?)"

    hyphen = "(?:#{partial}\\s+-\\s+\\g<partial>)"
    simple = "(?<simple>(?:<|>|>=|<=|~|\\^)?\\g<partial>)"

    "#{hyphen}|#{simple}(?:\\s+\\g<simple>)*"
  end
  private_class_method :range_pattern
end
end
end
