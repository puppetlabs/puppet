require 'puppet/util/tag_set'

module Puppet::Util::Tagging
  ValidTagRegex = /^[0-9A-Za-z_][0-9A-Za-z_:.-]*$/

  # Add a tag to the current tag set.
  # When a tag set is used for a scope, these tags will be added to all of
  # the objects contained in this scope when the objects are finished.
  #
  def tag(*ary)
    @tags ||= new_tags

    ary.flatten.each do |tag|
      name = tag.to_s.downcase
      # Add the tag before testing if it's valid since this means that
      # we never need to test the same valid tag twice. This speeds things
      # up since we get a lot of duplicates and rarely fail on bad tags
      if @tags.add?(name)
        # not seen before, so now we test if it is valid
        if name =~ ValidTagRegex
          # avoid adding twice by first testing if the string contains '::'
          @tags.merge(name.split('::')) if name.include?('::')
        else
          @tags.delete(name)
          fail(Puppet::ParseError, "Invalid tag '#{name}'")
        end
      end
    end
  end

  # Add a name to the current tag set. Silently ignore names that does not
  # represent valid tags.
  # 
  # Use this method instead of doing this:
  #
  #  tag(name) if is_valid?(name)
  #
  # since that results in testing the same string twice
  #
  def tag_if_valid(name)
    if name.is_a?(String) and name =~ ValidTagRegex
      name = name.downcase
      @tags ||= new_tags
      if @tags.add?(name) and name.include?('::')
        @tags.merge(name.split('::'))
      end
    end
  end

  # Is the receiver tagged with the given tags?
  def tagged?(*tags)
    not ( self.tags & tags.flatten.collect { |t| t.to_s } ).empty?
  end

  # Only use this method when copying known tags from one Tagging instance to another
  def set_tags(tag_source)
    @tags = tag_source.tags
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
    tag(*tags)
  end

  private

  def new_tags
    Puppet::Util::TagSet.new
  end
end
