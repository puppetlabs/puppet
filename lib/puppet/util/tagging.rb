require 'puppet/util/tag_set'

module Puppet::Util::Tagging
  # Add a tag to our current list.  These tags will be added to all
  # of the objects contained in this scope.
  def tag(*ary)
    @tags ||= new_tags

    qualified = []

    ary.collect { |tag| tag.to_s.downcase }.each do |tag|
      fail(Puppet::ParseError, "Invalid tag #{tag.inspect}") unless valid_tag?(tag)
      qualified << tag if tag.include?("::")
      @tags << tag unless @tags.include?(tag)
    end

    handle_qualified_tags( qualified )
  end

  # Answers if this resource is tagged with at least one of the given tags.
  #
  # The given tags are converted to downcased strings before the match is performed.
  #
  # @param *tags [String] splat of tags to look for
  # @return [Boolean] true if this instance is tagged with at least one of the provided tags
  #
  def tagged?(*tags)
    raw_tagged?(tags.collect {|t| t.to_s.downcase})
  end

  # Answers if this resource is tagged with at least one of the tags given in downcased string form.
  #
  # The method is a faster variant of the tagged? method that does no conversion of its
  # arguments.
  #
  # @param tag_array [Array[String]] array of tags to look for
  # @return [Boolean] true if this instance is tagged with at least one of the provided tags
  #
  def raw_tagged?(tag_array)
    my_tags = self.tags
    !tag_array.index { |t| my_tags.include?(t) }.nil?
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

  def handle_qualified_tags(qualified)
    qualified.each do |name|
      name.split("::").each do |tag|
        @tags << tag unless @tags.include?(tag)
      end
    end
  end

  ValidTagRegex = /^\w[-\w:.]*$/
  def valid_tag?(tag)
    tag.is_a?(String) and tag =~ ValidTagRegex
  end

  def new_tags
    Puppet::Util::TagSet.new
  end
end
