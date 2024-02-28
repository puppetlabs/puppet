# frozen_string_literal: true

module Puppet::Util::RpmCompare
  ARCH_LIST = %w[
    noarch i386 i686 ppc ppc64 armv3l armv4b armv4l armv4tl armv5tel
    armv5tejl armv6l armv7l m68kmint s390 s390x ia64 x86_64 sh3 sh4
  ].freeze

  ARCH_REGEX = Regexp.new(ARCH_LIST.join('|\.'))

  # This is an attempt at implementing RPM's
  # lib/rpmvercmp.c rpmvercmp(a, b) in Ruby.
  #
  # Some of the things in here look REALLY
  # UGLY and/or arbitrary. Our goal is to
  # match how RPM compares versions, quirks
  # and all.
  #
  # I've kept a lot of C-like string processing
  # in an effort to keep this as identical to RPM
  # as possible.
  #
  # returns 1 if str1 is newer than str2,
  #         0 if they are identical
  #        -1 if str1 is older than str2
  def rpmvercmp(str1, str2)
    return 0 if str1 == str2

    front_strip_re = /^[^A-Za-z0-9~]+/

    while str1.length > 0 or str2.length > 0
      # trim anything that's in front_strip_re and != '~' off the beginning of each string
      str1 = str1.gsub(front_strip_re, '')
      str2 = str2.gsub(front_strip_re, '')

      # "handle the tilde separator, it sorts before everything else"
      if str1 =~ /^~/ && str2 =~ /^~/
        # if they both have ~, strip it
        str1 = str1[1..]
        str2 = str2[1..]
        next
      elsif str1 =~ /^~/
        return -1
      elsif str2 =~ /^~/
        return 1
      end

      break if str1.length == 0 or str2.length == 0

      # "grab first completely alpha or completely numeric segment"
      isnum = false
      # if the first char of str1 is a digit, grab the chunk of continuous digits from each string
      if str1 =~ /^[0-9]+/
        if str1 =~ /^[0-9]+/
          segment1 = $~.to_s
          str1 = $~.post_match
        else
          segment1 = ''
        end
        if str2 =~ /^[0-9]+/
          segment2 = $~.to_s
          str2 = $~.post_match
        else
          segment2 = ''
        end
        isnum = true
      # else grab the chunk of continuous alphas from each string (which may be '')
      else
        if str1 =~ /^[A-Za-z]+/
          segment1 = $~.to_s
          str1 = $~.post_match
        else
          segment1 = ''
        end
        if str2 =~ /^[A-Za-z]+/
          segment2 = $~.to_s
          str2 = $~.post_match
        else
          segment2 = ''
        end
      end

      # if the segments we just grabbed from the strings are different types (i.e. one numeric one alpha),
      # where alpha also includes ''; "numeric segments are always newer than alpha segments"
      if segment2.length == 0
        return 1 if isnum

        return -1
      end

      if isnum
        # "throw away any leading zeros - it's a number, right?"
        segment1 = segment1.gsub(/^0+/, '')
        segment2 = segment2.gsub(/^0+/, '')
        # "whichever number has more digits wins"
        return 1 if segment1.length > segment2.length
        return -1 if segment1.length < segment2.length
      end

      # "strcmp will return which one is greater - even if the two segments are alpha
      # or if they are numeric. don't return if they are equal because there might
      # be more segments to compare"
      rc = segment1 <=> segment2
      return rc if rc != 0
    end # end while loop

    # if we haven't returned anything yet, "whichever version still has characters left over wins"
    return 1 if str1.length > str2.length
    return -1 if str1.length < str2.length

    0
  end

  # parse a rpm "version" specification
  # this re-implements rpm's
  # rpmUtils.miscutils.stringToVersion() in ruby
  def rpm_parse_evr(full_version)
    epoch_index = full_version.index(':')
    if epoch_index
      epoch = full_version[0, epoch_index]
      full_version = full_version[epoch_index + 1, full_version.length]
    else
      epoch = nil
    end
    begin
      epoch = String(Integer(epoch))
    rescue
      # If there are non-digits in the epoch field, default to nil
      epoch = nil
    end
    release_index = full_version.index('-')
    if release_index
      version = full_version[0, release_index]
      release = full_version[release_index + 1, full_version.length]
      arch = release.scan(ARCH_REGEX)[0]
      if arch
        architecture = arch.delete('.')
        release.gsub!(ARCH_REGEX, '')
      end
    else
      version = full_version
      release = nil
    end
    return { :epoch => epoch, :version => version, :release => release, :arch => architecture }
  end

  # this method is a native implementation of the
  # compare_values function in rpm's python bindings,
  # found in python/header-py.c, as used by rpm.
  def compare_values(s1, s2)
    return 0 if s1.nil? && s2.nil?
    return 1 if (!s1.nil?) && s2.nil?
    return -1 if s1.nil? && (!s2.nil?)

    return rpmvercmp(s1, s2)
  end

  # how rpm compares two package versions:
  # rpmUtils.miscutils.compareEVR(), which massages data types and then calls
  # rpm.labelCompare(), found in rpm.git/python/header-py.c, which
  # sets epoch to 0 if null, then compares epoch, then ver, then rel
  # using compare_values() and returns the first non-0 result, else 0.
  # This function combines the logic of compareEVR() and labelCompare().
  #
  # "version_should" can be v, v-r, or e:v-r.
  # "version_is" will always be at least v-r, can be e:v-r
  #
  # return 1: a is newer than b
  #        0: a and b are the same version
  #       -1: b is newer than a
  def rpm_compare_evr(should, is)
    # pass on to rpm labelCompare
    should_hash = rpm_parse_evr(should)
    is_hash = rpm_parse_evr(is)

    unless should_hash[:epoch].nil?
      rc = compare_values(should_hash[:epoch], is_hash[:epoch])
      return rc unless rc == 0
    end

    rc = compare_values(should_hash[:version], is_hash[:version])
    return rc unless rc == 0

    # here is our special case, PUP-1244.
    # if should_hash[:release] is nil (not specified by the user),
    # and comparisons up to here are equal, return equal. We need to
    # evaluate to whatever level of detail the user specified, so we
    # don't end up upgrading or *downgrading* when not intended.
    #
    # This should NOT be triggered if we're trying to ensure latest.
    return 0 if should_hash[:release].nil?

    rc = compare_values(should_hash[:release], is_hash[:release])

    return rc
  end
end
