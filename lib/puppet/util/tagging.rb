require 'puppet/util/tag_set'

module Puppet::Util::Tagging
  ValidTagRegex = /^\w[-\w:.]*$/

  # Add a tag to the current tag set.
  # When a tag set is used for a scope, these tags will be added to all of
  # the objects contained in this scope when the objects are finished.
  #
  def tag(*ary)
    @tags ||= new_tags

    ary.flatten.each do |tag|
      name = tag.to_s.downcase
      if name =~ ValidTagRegex
        @tags << name
        name.split("::").each do |section|
          @tags << section
        end
      else
        fail(Puppet::ParseError, "Invalid tag '#{name}'")
      end
    end
  end

  # Is the receiver tagged with at least one of the given tags?
  #
  # @param *tags [String] splat of tags to look for
  # @return [Boolean] true if this instance is tagged with at least one of the provided tags
  #
  def tagged?(*tags)
    raw_tagged?(tags.collect {|t| t.to_s.downcase})
  end

  # Faster variant of the tagged method that does no conversion of its
  # arguments. Instead it's assumed that the arguments already are
  # downcased strings.
  #
  # @param tag_array [Array] array of tags to look for
  # @return [Boolean] true if this instance is tagged with at least one of the provided tags
  #
  def raw_tagged?(tag_array)
    my_tags = self.tags
    not tag_array.index { |t| my_tags.include?(t) }.nil?
  end

  # Return a copy of the tag list, so someone can't ask for our tags
  # and then modify them.
  def tags
    @tags ||= new_tags
    @tags.dup
  end

  def tags=(tags)
    @tags = new_tags

    return if tags.nil? or tags == ""

    tags = tags.strip.split(/\s*,\s*/) if tags.is_a?(String)
    tags.each {|t| tag(t) }
  end

  private

  def valid_tag?(tag)
    tag.is_a?(String) and tag =~ ValidTagRegex
  end

  def new_tags
    Puppet::Util::TagSet.new
  end
end
