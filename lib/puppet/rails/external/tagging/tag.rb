class Tag < ActiveRecord::Base
  has_many :taggings

  def self.tags(options = {})
    query = "select tags.id, name, count(*) as count"
    query << " from taggings, tags"
    query << " where tags.id = tag_id"
    query << " group by tag_id"
    query << " order by #{options[:order]}" if options[:order] != nil
    query << " limit #{options[:limit]}" if options[:limit] != nil
    tags = Tag.find_by_sql(query)
  end

  def self.parse(list)
    tag_names = []

    # first, pull out the quoted tags
    list.gsub!(/\"(.*?)\"\s*/ ) { tag_names << $1; "" }

    # then, replace all commas with a space
    list.gsub!(/,/, " ")

    # then, get whatever's left
    tag_names.concat list.split(/\s/)

    # strip whitespace from the names
    tag_names = tag_names.map { |t| t.strip }

    # delete any blank tag names
    tag_names = tag_names.delete_if { |t| t.empty? }
    
    return tag_names
  end

  def tagged
    @tagged ||= taggings.collect { |tagging| tagging.taggable }
  end
  
  def on(taggable)
    taggings.build :taggable => taggable
  end
  
  def ==(comparison_object)
    super || name == comparison_object.to_s
  end
  
  def to_s
    name
  end
end
