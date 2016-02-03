require 'puppet/util/monkey_patches'

# We need to subclass Numeric to force range comparisons not to try to iterate over SemVer
# and instead use numeric comparisons (eg >, <, >=, <=)
class SemVer < Numeric
  include Comparable

  VERSION = /^v?(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z-]*|)$/
  SIMPLE_RANGE = /^v?(\d+|[xX])(?:\.(\d+|[xX])(?:\.(\d+|[xX]))?)?$/

  def self.valid?(ver)
    VERSION =~ ver
  end

  def self.find_matching(pattern, versions)
    versions.select { |v| v.matched_by?("#{pattern}") }.sort.last
  end

  def self.pre(vstring)
    vstring =~ /-/ ? vstring : vstring + '-'
  end

  def self.[](range)
    range.gsub(/([><=])\s+/, '\1').split(/\b\s+(?!-)/).map do |r|
      case r
      when SemVer::VERSION
        SemVer.new(pre(r)) .. SemVer.new(r)
      when SemVer::SIMPLE_RANGE
        r += ".0" unless SemVer.valid?(r.gsub(/x/i, '0'))
        SemVer.new(r.gsub(/x/i, '0'))...SemVer.new(r.gsub(/(\d+)\.x/i) { "#{$1.to_i + 1}.0" } + '-')
      when /\s+-\s+/
        a, b = r.split(/\s+-\s+/)
        SemVer.new(pre(a)) .. SemVer.new(b)
      when /^~/
        ver = r.sub(/~/, '').split('.').map(&:to_i)
        start = (ver + [0] * (3 - ver.length)).join('.')

        ver.pop unless ver.length == 1
        ver[-1] = ver.last + 1

        finish = (ver + [0] * (3 - ver.length)).join('.')
        SemVer.new(pre(start)) ... SemVer.new(pre(finish))
      when /^>=/
        ver = r.sub(/^>=/, '')
        SemVer.new(pre(ver)) .. SemVer::MAX
      when /^<=/
        ver = r.sub(/^<=/, '')
        SemVer::MIN .. SemVer.new(ver)
      when /^>/
        if r =~ /-/
          ver = [r[1..-1]]
        else
          ver = r.sub(/^>/, '').split('.').map(&:to_i)
          ver[2] = ver.last + 1
        end
        SemVer.new(ver.join('.') + '-') .. SemVer::MAX
      when /^</
        ver = r.sub(/^</, '')
        SemVer::MIN ... SemVer.new(pre(ver))
      else
        (1..1)
      end
    end.inject { |a,e| a & e }
  end

  attr_reader :major, :minor, :tiny, :special

  def initialize(ver)
    unless SemVer.valid?(ver)
      raise ArgumentError.new("Invalid version string '#{ver}'!")
    end

    @major, @minor, @tiny, @special = VERSION.match(ver).captures.map do |x|
      # Because Kernel#Integer tries to interpret hex and octal strings, which
      # we specifically do not want, and which cannot be overridden in 1.8.7.
      Float(x).to_i rescue x
    end
  end

  def <=>(other)
    # Note that prior to ruby 2.3.0, if a <=> method threw an exception, ruby
    # would silently rescue the exception and return nil from <=> (which causes
    # the derived == comparison to return false). Starting in ruby 2.3.0, this
    # behavior changed and the exception is actually thrown. Some comments at:
    # https://bugs.ruby-lang.org/issues/7688
    #
    # SemVer#initialize above throws an ArgumentError given an invalid
    # version string. So, to preserve the ability to use the == operator
    # between a SemVer object and an invalid version string, we take care here
    # to do the valid? check before constructing the SemVer object (i.e.
    # so that a == comparison doesn't throw an exception, but just returns
    # false.)
    unless other.is_a? SemVer
      return nil unless SemVer.valid?(other)
      other = SemVer.new("#{other}")
    end

    return self.major <=> other.major unless self.major == other.major
    return self.minor <=> other.minor unless self.minor == other.minor
    return self.tiny  <=> other.tiny  unless self.tiny  == other.tiny

    return 0  if self.special  == other.special
    return 1  if self.special  == ''
    return -1 if other.special == ''

    return self.special <=> other.special
  end

  def matched_by?(pattern)
    # For the time being, this is restricted to exact version matches and
    # simple range patterns.  In the future, we should implement some or all of
    # the comparison operators here:
    # https://github.com/isaacs/node-semver/blob/d474801/semver.js#L340

    case pattern
    when SIMPLE_RANGE
      pattern = SIMPLE_RANGE.match(pattern).captures
      pattern[1] = @minor unless pattern[1] && pattern[1] !~ /x/i
      pattern[2] = @tiny  unless pattern[2] && pattern[2] !~ /x/i
      [@major, @minor, @tiny] == pattern.map { |x| x.to_i }
    when VERSION
      self == SemVer.new(pattern)
    else
      false
    end
  end

  def inspect
    @vstring || "v#{@major}.#{@minor}.#{@tiny}#{@special}"
  end
  alias :to_s :inspect

  MIN = SemVer.new('0.0.0-')
  MIN.instance_variable_set(:@vstring, 'vMIN')

  MAX = SemVer.new('8.0.0')
  MAX.instance_variable_set(:@major, Float::INFINITY) # => Infinity
  MAX.instance_variable_set(:@vstring, 'vMAX')
end
