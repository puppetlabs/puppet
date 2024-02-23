# frozen_string_literal: true

module Puppet::Util::Package::Version
  class Pip
    include Comparable

    VERSION_PATTERN = "
      v?
      (?:
        (?:(?<epoch>[0-9]+)!)?                              # epoch
        (?<release>[0-9]+(?:\\.[0-9]+)*)                    # release segment
        (?<pre>                                             # pre-release
          [-_\\.]?
          (?<pre_l>(a|b|c|rc|alpha|beta|pre|preview))
          [-_\\.]?
          (?<pre_n>[0-9]+)?
        )?
        (?<post>                                            # post release
          (?:-(?<post_n1>[0-9]+))
          |
          (?:
            [-_\\.]?
            (?<post_l>post|rev|r)
            [-_\\.]?
            (?<post_n2>[0-9]+)?
          )
        )?
        (?<dev>                                             # dev release
          [-_\\.]?
          (?<dev_l>dev)
          [-_\\.]?
          (?<dev_n>[0-9]+)?
        )?
      )
      (?:\\+(?<local>[a-z0-9]+(?:[-_\\.][a-z0-9]+)*))?      # local version
    "

    def self.parse(version)
      raise ValidationFailure, version.to_s unless version.is_a? String

      matched = version.match(Regexp.new(("^\\s*") + VERSION_PATTERN + ("\\s*$"), Regexp::EXTENDED | Regexp::MULTILINE | Regexp::IGNORECASE))
      raise ValidationFailure, version unless matched

      new(matched)
    end

    def self.compare(version_a, version_b)
      version_a = parse(version_a) unless version_a.is_a?(self)
      version_b = parse(version_b) unless version_b.is_a?(self)

      version_a <=> version_b
    end

    def to_s
      parts = []

      parts.push("#{@epoch_data}!")           if @epoch_data && @epoch_data != 0
      parts.push(@release_data.join("."))     if @release_data
      parts.push(@pre_data.join)              if @pre_data
      parts.push(".post#{@post_data[1]}")     if @post_data
      parts.push(".dev#{@dev_data[1]}")       if @dev_data
      parts.push("+#{@local_data.join(".")}") if @local_data

      parts.join
    end
    alias inspect to_s

    def eql?(other)
      other.is_a?(self.class) && key.eql?(other.key)
    end
    alias == eql?

    def <=>(other)
      raise ValidationFailure, other.to_s unless other.is_a?(self.class)

      compare(key, other.key)
    end

    attr_reader :key

    private

    def initialize(matched)
      @epoch_data   = matched[:epoch].to_i
      @release_data = matched[:release].split('.').map(&:to_i)                                       if matched[:release]
      @pre_data     = parse_letter_version(matched[:pre_l], matched[:pre_n])                         if matched[:pre_l]  || matched[:pre_n]
      @post_data    = parse_letter_version(matched[:post_l], matched[:post_n1] || matched[:post_n2]) if matched[:post_l] || matched[:post_n1] || matched[:post_n2]
      @dev_data     = parse_letter_version(matched[:dev_l], matched[:dev_n])                         if matched[:dev_l]  || matched[:dev_n]
      @local_data   = parse_local_version(matched[:local])                                           if matched[:local]

      @key = compose_key(@epoch_data, @release_data, @pre_data, @post_data, @dev_data, @local_data)
    end

    def parse_letter_version(letter, number)
      if letter
        number ||= 0
        letter.downcase!

        if letter == "alpha"
          letter = "a"
        elsif letter == "beta"
          letter = "b"
        elsif ["c", "pre", "preview"].include?(letter)
          letter = "rc"
        elsif ["rev", "r"].include?(letter)
          letter = "post"
        end

        return [letter, number.to_i]
      end

      ["post", number.to_i] if !letter && number
    end

    def parse_local_version(local_version)
      local_version.split(/[\\._-]/).map { |part| part =~ /[0-9]+/ && part !~ /[a-zA-Z]+/ ? part.to_i : part.downcase } if local_version
    end

    def compose_key(epoch, release, pre, post, dev, local)
      release_key = release.reverse
      release_key.each_with_index do |element, index|
        break unless element == 0

        release_key.delete_at(index) unless release_key.at(index + 1) != 0
      end
      release_key.reverse!

      if !pre && !post && dev
        pre_key = -Float::INFINITY
      else
        pre_key = pre || Float::INFINITY
      end

      post_key = post || -Float::INFINITY

      dev_key = dev || Float::INFINITY

      if !local
        local_key = [[-Float::INFINITY, ""]]
      else
        local_key = local.map { |i| (i.is_a? Integer) ? [i, ""] : [-Float::INFINITY, i] }
      end

      [epoch, release_key, pre_key, post_key, dev_key, local_key]
    end

    def compare(this, other)
      if (this.is_a? Array) && (other.is_a? Array)
        this  << -Float::INFINITY if this.length < other.length
        other << -Float::INFINITY if this.length > other.length

        this.each_with_index do |element, index|
          return compare(element, other.at(index)) if element != other.at(index)
        end
      elsif (this.is_a? Array) && !(other.is_a? Array)
        raise Puppet::Error, "Cannot compare #{this} (Array) with #{other} (#{other.class}). Only ±Float::INFINITY accepted." unless other.abs == Float::INFINITY

        return other == -Float::INFINITY ? 1 : -1
      elsif !(this.is_a? Array) && (other.is_a? Array)
        raise Puppet::Error, "Cannot compare #{this} (#{this.class}) with #{other} (Array). Only ±Float::INFINITY accepted." unless this.abs == Float::INFINITY

        return this == -Float::INFINITY ? -1 : 1
      end
      this <=> other
    end

    class ValidationFailure < ArgumentError
      def initialize(version)
        super("#{version} is not a valid python package version. Please refer to https://www.python.org/dev/peps/pep-0440/.")
      end
    end
  end
end
