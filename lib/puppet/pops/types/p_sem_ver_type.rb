module Puppet::Pops
module Types

# A Puppet Language Type that exposes the {{SemanticPuppet::Version}} and {{SemanticPuppet::VersionRange}}.
# The version type is parameterized with version ranges.
#
# @api public
class PSemVerType < PScalarType
  def self.register_ptype(loader, ir)
    create_ptype(loader, ir, 'ScalarType',
       'ranges' => {
         KEY_TYPE => PArrayType.new(PVariantType.new([PSemVerRangeType::DEFAULT,PStringType::NON_EMPTY])),
         KEY_VALUE => []
       }
    )
  end

  attr_reader :ranges

  def initialize(ranges)
    ranges = ranges.map { |range| range.is_a?(SemanticPuppet::VersionRange) ? range : SemanticPuppet::VersionRange.parse(range) }
    ranges = merge_ranges(ranges) if ranges.size > 1
    @ranges = ranges
  end

  def instance?(o, guard = nil)
    o.is_a?(SemanticPuppet::Version) && (@ranges.empty? || @ranges.any? {|range| range.include?(o) })
  end

  def eql?(o)
    self.class == o.class && @ranges == o.ranges
  end

  def hash?
    super ^ @ranges.hash
  end

  # Creates a SemVer version from the given _version_ argument. If the argument is `nil` or
  # a {SemanticPuppet::Version}, it is returned. If it is a {String}, it will be parsed into a
  # {SemanticPuppet::Version}. Any other class will raise an {ArgumentError}.
  #
  # @param version [SemanticPuppet::Version,String,nil] the version to convert
  # @return [SemanticPuppet::Version] the converted version
  # @raise [ArgumentError] when the argument cannot be converted into a version
  #
  def self.convert(version)
    case version
    when nil, SemanticPuppet::Version
      version
    when String
      SemanticPuppet::Version.parse(version)
    else
      raise ArgumentError, "Unable to convert a #{version.class.name} to a SemVer"
    end
  end

  # @api private
  def self.new_function(type)
    @new_function ||= Puppet::Functions.create_loaded_function(:new_Version, type.loader) do
      local_types do
        type 'PositiveInteger = Integer[0,default]'
        type 'SemVerQualifier = Pattern[/\A(?<part>[0-9A-Za-z-]+)(?:\.\g<part>)*\Z/]'
        type "SemVerPattern = Pattern[/\\A#{SemanticPuppet::Version::REGEX_FULL}\\Z/]"
        type 'SemVerHash = Struct[{major=>PositiveInteger,minor=>PositiveInteger,patch=>PositiveInteger,Optional[prerelease]=>SemVerQualifier,Optional[build]=>SemVerQualifier}]'
      end

      # Creates a SemVer from a string as specified by http://semver.org/
      #
      dispatch :from_string do
        param 'SemVerPattern', :str
      end

      # Creates a SemVer from integers, prerelease, and build arguments
      #
      dispatch :from_args do
        param 'PositiveInteger', :major
        param 'PositiveInteger', :minor
        param 'PositiveInteger', :patch
        optional_param 'SemVerQualifier', :prerelease
        optional_param 'SemVerQualifier', :build
      end

      # Same as #from_args but each argument is instead given in a Hash
      #
      dispatch :from_hash do
        param 'SemVerHash', :hash_args
      end

      argument_mismatch :on_error do
        param 'String', :str
      end

      def from_string(str)
        SemanticPuppet::Version.parse(str)
      end

      def from_args(major, minor, patch, prerelease = nil, build = nil)
        SemanticPuppet::Version.new(major, minor, patch, prerelease, build)
      end

      def from_hash(hash)
        SemanticPuppet::Version.new(hash['major'], hash['minor'], hash['patch'], hash['prerelease'], hash['build'])
      end

      def on_error(str)
        _("The string '%{str}' cannot be converted to a SemVer") % { str: str }
      end
    end
  end

  DEFAULT = PSemVerType.new(EMPTY_ARRAY)

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
