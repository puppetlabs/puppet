class Puppet::Type
    attr_reader :tags

    # Add a new tag.
    def tag(tag)
        tag = tag.intern if tag.is_a? String
        unless @tags.include? tag
            @tags << tag
        end
    end

    # Define the initial list of tags.
    def tags=(list)
        list = [list] unless list.is_a? Array

        @tags = list.collect do |t|
            case t
            when String: t.intern
            when Symbol: t
            else
                self.warning "Ignoring tag %s of type %s" % [tag.inspect, tag.class]
            end
        end

        @tags << self.class.name unless @tags.include?(self.class.name)
    end

    # Figure out of any of the specified tags apply to this object.  This is an
    # OR operation.
    def tagged?(tags)
        tags = [tags] unless tags.is_a? Array

        tags = tags.collect { |t| t.intern }

        return tags.find { |tag| @tags.include? tag }
    end
end

# $Id$
