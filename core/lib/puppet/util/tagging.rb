# Created on 2008-01-19
# Copyright Luke Kanies

# A common module to handle tagging.
#
# So, do you want the bad news or the good news first?
#
# The bad news is that using an array here is hugely costly compared to using
# a hash.  Like, the same speed empty, 50 percent slower with one item, and
# 300 percent slower at 6 - one of our common peaks for tagging items.
#
# ...and that assumes an efficient implementation, just using include?.  These
# methods have even more costs hidden in them.
#
# The good news is that this module has no API.  Various objects directly
# interact with their `@tags` member as an array, or dump it directly in YAML,
# or whatever.
#
# So, er, you can't actually change this.  No matter how much you want to be
# cause it is inefficient in both CPU and object allocation terms.
#
# Good luck, my friend. --daniel 2012-07-17
module Puppet::Util::Tagging
  # Add a tag to our current list.  These tags will be added to all
  # of the objects contained in this scope.
  def tag(*ary)
    @tags ||= []

    qualified = []

    ary.collect { |tag| tag.to_s.downcase }.each do |tag|
      fail(Puppet::ParseError, "Invalid tag #{tag.inspect}") unless valid_tag?(tag)
      qualified << tag if tag.include?("::")
      @tags << tag unless @tags.include?(tag)
    end

    handle_qualified_tags( qualified )
  end

  # Are we tagged with the provided tag?
  def tagged?(*tags)
    not ( self.tags & tags.flatten.collect { |t| t.to_s } ).empty?
  end

  # Return a copy of the tag list, so someone can't ask for our tags
  # and then modify them.
  def tags
    @tags ||= []
    @tags.dup
  end

  def tags=(tags)
    @tags = []

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
end
