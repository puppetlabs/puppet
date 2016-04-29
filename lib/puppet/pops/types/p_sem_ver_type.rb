module Puppet::Pops
module Types

# A Puppet Language Type that exposes the {{Semantic::Version}} and {{Semantic::VersionRange}}.
# The version type is parameterized with version ranges.
#
# @api public
class PSemVerType < PScalarType
  attr_reader :ranges

  def initialize(*ranges)
    ranges = ranges.map { |range| range.is_a?(Semantic::VersionRange) ? range : Semantic::VersionRange.parse(range) }
    ranges = merge_ranges(ranges) if ranges.size > 1
    @ranges = ranges
  end

  def instance?(o, guard = nil)
    o.is_a?(Semantic::Version) && (@ranges.empty? || @ranges.any? {|range| range.include?(o) })
  end

  def eql?(o)
    self.class == o.class && @ranges == o.ranges
  end

  def hash?
    super ^ @ranges.hash
  end

  # @api private
  def self.parts_pattern
    part = "(?<part>[0-9A-Za-z-]+)"
    "(?<parts>#{part}(?:\\.\\g<part>)*)"
  end

  # @api private
  def self.version_pattern
    nr = '(?<nr>0|[1-9][0-9]*)'
    "#{nr}\\.\\g<nr>\\.\\g<nr>(?:-#{parts_pattern})?(?:\\+\\g<parts>)?"
  end

  # @api private
  def self.new_function(_, loader)
    version_expr = "\\A#{version_pattern}\\Z"
    parts_expr = "\\A#{parts_pattern}\\Z"
    @@new_function ||= Puppet::Functions.create_loaded_function(:new_Version, loader) do
      local_types do
        type 'Unsigned = Integer[0,default]'
        type "Qualifier = Pattern[/#{parts_expr}/]"
      end

      dispatch :from_string do
        param "Pattern[/#{version_expr}/]", :str
      end

      dispatch :from_args do
        param 'Unsigned', :major
        param 'Unsigned', :minor
        param 'Unsigned', :patch
        optional_param 'Qualifier', :prerelease
        optional_param 'Qualifier', :build
      end

      dispatch :from_hash do
        param(
          'Struct[{major=>Unsigned,minor=>Unsigned,patch=>Unsigned,Optional[prerelease]=>Qualifier,Optional[build]=>Qualifier}]',
          :hash_args)
      end

      def from_string(str)
        Semantic::Version.parse(str)
      end

      def from_args(major, minor, patch, prerelease = nil, build = nil)
        Semantic::Version.new(major, minor, patch, prerelease, build)
      end

      def from_hash(hash)
        Semantic::Version.new(hash['major'], hash['minor'], hash['patch'], hash['prerelease'], hash['build'])
      end
    end
  end

  DEFAULT = PSemVerType.new

  protected

  def _assignable?(o, guard)
    return false unless o.class == self.class
    return true if @ranges.empty?
    return false if o.ranges.empty?

    # All ranges in o must be covered by at least one range in self
    o.ranges.all? do |o_range|
      @ranges.any? do |range|
        PSemVerRangeType.covered_by?(o_range, range)
      end
    end
  end

  # @api private
  def merge_ranges(ranges)
    result = []
    until ranges.empty?
      unmerged = []
      x = ranges.pop
      result << ranges.inject(x) do |memo, y|
        merged = PSemVerRangeType.merge(memo, y)
        if merged.nil?
          unmerged << y
        else
          memo = merged
        end
        memo
      end
      ranges = unmerged
    end
    result.reverse!
  end
end
end
end