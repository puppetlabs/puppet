# frozen_string_literal: true

require_relative '../../../../puppet/util/rpm_compare'

module Puppet::Util::Package::Version
  class Rpm < Numeric
    # provides Rpm parsing and comparison
    extend Puppet::Util::RpmCompare
    include Puppet::Util::RpmCompare
    include Comparable

    class ValidationFailure < ArgumentError; end

    attr_reader :epoch, :version, :release, :arch

    def self.parse(ver)
      raise ValidationFailure unless ver.is_a?(String)

      version = rpm_parse_evr(ver)
      new(version[:epoch], version[:version], version[:release], version[:arch]).freeze
    end

    def to_s
      version_found = ''.dup
      version_found += "#{@epoch}:" if @epoch
      version_found += @version
      version_found += "-#{@release}" if @release
      version_found
    end
    alias inspect to_s

    def eql?(other)
      other.is_a?(self.class) &&
        @epoch.eql?(other.epoch) &&
        @version.eql?(other.version) &&
        @release.eql?(other.release) &&
        @arch.eql?(other.arch)
    end
    alias == eql?

    def <=>(other)
      raise ArgumentError, _("Cannot compare, as %{other} is not a Rpm Version") % { other: other } unless other.is_a?(self.class)

      rpm_compare_evr(to_s, other.to_s)
    end

    private

    # overwrite rpm_compare_evr to treat no epoch as zero epoch
    # in order to compare version correctly
    #
    # returns 1 if a is newer than b,
    #         0 if they are identical
    #        -1 if a is older than b
    def rpm_compare_evr(a, b)
      a_hash = rpm_parse_evr(a)
      b_hash = rpm_parse_evr(b)

      a_hash[:epoch] ||= '0'
      b_hash[:epoch] ||= '0'

      rc = compare_values(a_hash[:epoch], b_hash[:epoch])
      return rc unless rc == 0

      super(a, b)
    end

    def initialize(epoch, version, release, arch)
      @epoch   = epoch
      @version = version
      @release = release
      @arch    = arch
    end
  end
end
