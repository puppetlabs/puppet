require 'puppet/util/tag_set'

module Puppet::Util::Tagging
  ValidTagRegex = /^\w[-\w:.]*$/

  # Add a tag to our current list.  These tags will be added to all
  # of the objects contained in this scope.
  def tag(*ary)
    @tags ||= new_tags

    ary.each do |tag|
      name = tag.to_s.downcase
      if name =~ ValidTagRegex
        @tags << name
        name.split("::").each do |section|
          @tags << section
        end
      else
        fail(Puppet::ParseError, "Invalid tag #{name}")
      end
    end
  end

  # Are we tagged with the provided tag?
  def tagged?(*tags)
    not ( self.tags & tags.flatten.collect { |t| t.to_s } ).empty?
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
