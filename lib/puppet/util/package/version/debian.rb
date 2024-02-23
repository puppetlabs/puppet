# frozen_string_literal: true

module Puppet::Util::Package::Version
  class Debian < Numeric
    include Comparable

    # Version string matching regexes
    REGEX_EPOCH = '(?:([0-9]+):)?'
    # alphanumerics and the characters . + - ~ , starts with a digit, ~ only of debian_revision is present
    REGEX_UPSTREAM_VERSION = '([\.\+~0-9a-zA-Z-]+?)'
    # alphanumerics and the characters + . ~
    REGEX_DEBIAN_REVISION = '(?:-([\.\+~0-9a-zA-Z]*))?'

    REGEX_FULL    = REGEX_EPOCH + REGEX_UPSTREAM_VERSION + REGEX_DEBIAN_REVISION.freeze
    REGEX_FULL_RX = /\A#{REGEX_FULL}\Z/

    class ValidationFailure < ArgumentError; end

    def self.parse(ver)
      raise ValidationFailure, "Unable to parse '#{ver}' as a string" unless ver.is_a?(String)

      match, epoch, upstream_version, debian_revision = *ver.match(REGEX_FULL_RX)

      raise ValidationFailure, "Unable to parse '#{ver}' as a debian version identifier" unless match

      new(epoch.to_i, upstream_version, debian_revision).freeze
    end

    def to_s
      s = @upstream_version
      s = "#{@epoch}:#{s}" if @epoch != 0
      s = "#{s}-#{@debian_revision}" if @debian_revision
      s
    end
    alias inspect to_s

    def eql?(other)
      other.is_a?(self.class) &&
        @epoch.eql?(other.epoch) &&
        @upstream_version.eql?(other.upstream_version) &&
        @debian_revision.eql?(other.debian_revision)
    end
    alias == eql?

    def <=>(other)
      return nil unless other.is_a?(self.class)

      cmp = @epoch <=> other.epoch
      if cmp == 0
        cmp = compare_upstream_version(other)
        if cmp == 0
          cmp = compare_debian_revision(other)
        end
      end
      cmp
    end

    attr_reader :epoch, :upstream_version, :debian_revision

    private

    def initialize(epoch, upstream_version, debian_revision)
      @epoch            = epoch
      @upstream_version = upstream_version
      @debian_revision  = debian_revision
    end

    def compare_upstream_version(other)
      mine = @upstream_version
      yours = other.upstream_version
      compare_debian_versions(mine, yours)
    end

    def compare_debian_revision(other)
      mine = @debian_revision
      yours = other.debian_revision
      compare_debian_versions(mine, yours)
    end

    def compare_debian_versions(mine, yours)
      #   First the initial part of each string consisting entirely of non-digit characters is determined.
      # These two parts (one of which may be empty) are compared lexically. If a difference is found it is
      # returned. The lexical comparison is a comparison of ASCII values modified so that all the letters
      # sort earlier than all the non-letters and so that a tilde sorts before anything, even the end of a
      # part. For example, the following parts are in sorted order from earliest to latest: ~~, ~~a, ~, the
      # empty part, a.
      #
      #   Then the initial part of the remainder of each string which consists entirely of digit characters
      # is determined. The numerical values of these two parts are compared, and any difference found is
      # returned as the result of the comparison. For these purposes an empty string (which can only occur
      # at the end of one or both version strings being compared) counts as zero.
      #
      #   These two steps (comparing and removing initial non-digit strings and initial digit strings) are
      # repeated until a difference is found or both strings are exhausted.

      mine_index = 0
      yours_index = 0
      cmp = 0
      mine ||= ''
      yours ||= ''
      while mine_index < mine.length && yours_index < yours.length && cmp == 0
        # handle ~
        _mymatch, mytilde = *match_tildes(mine.slice(mine_index..-1))
        mytilde ||= ''

        _yoursmatch, yourstilde = *match_tildes(yours.slice(yours_index..-1))
        yourstilde ||= ''

        cmp = -1 * (mytilde.length <=> yourstilde.length)
        mine_index += mytilde.length
        yours_index += yourstilde.length

        next unless cmp == 0 # handle letters

        _mymatch, myletters = *match_letters(mine.slice(mine_index..-1))
        myletters ||= ''

        _yoursmatch, yoursletters = *match_letters(yours.slice(yours_index..-1))
        yoursletters ||= ''

        cmp = myletters <=> yoursletters
        mine_index += myletters.length
        yours_index += yoursletters.length

        next unless cmp == 0 # handle nonletters except tilde

        _mymatch, mynon_letters = *match_non_letters(mine.slice(mine_index..-1))
        mynon_letters ||= ''

        _yoursmatch, yoursnon_letters = *match_non_letters(yours.slice(yours_index..-1))
        yoursnon_letters ||= ''

        cmp = mynon_letters <=> yoursnon_letters
        mine_index += mynon_letters.length
        yours_index += yoursnon_letters.length

        next unless cmp == 0 # handle digits

        _mymatch, mydigits = *match_digits(mine.slice(mine_index..-1))
        mydigits ||= ''

        _yoursmatch, yoursdigits = *match_digits(yours.slice(yours_index..-1))
        yoursdigits ||= ''

        cmp = mydigits.to_i <=> yoursdigits.to_i
        mine_index += mydigits.length
        yours_index += yoursdigits.length
      end
      if cmp == 0
        if mine_index < mine.length && match_tildes(mine[mine_index])
          cmp = -1
        elsif yours_index < yours.length && match_tildes(yours[yours_index])
          cmp = 1
        else
          cmp = mine.length <=> yours.length
        end
      end
      cmp
    end

    def match_digits(a)
      a.match(/^([0-9]+)/)
    end

    def match_non_letters(a)
      a.match(/^([\.\+-]+)/)
    end

    def match_tildes(a)
      a.match(/^(~+)/)
    end

    def match_letters(a)
      a.match(/^([A-Za-z]+)/)
    end
  end
end
