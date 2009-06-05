class Puppet::Rails::ResourceTag < ActiveRecord::Base
    belongs_to :puppet_tag
    belongs_to :resource

    def to_label
      "#{self.puppet_tag.name}"
    end

    # returns an array of hash containing tags of resource
    def self.find_all_tags_from_resource(db_resource)
        tags = db_resource.connection.select_all("SELECT t.id, t.resource_id, p.name FROM resource_tags as t INNER JOIN puppet_tags as p ON t.puppet_tag_id=p.id WHERE t.resource_id=%s" % db_resource.id)
        tags.each do |val|
            val['resource_id'] = Integer(val['resource_id'])
        end
        tags
    end

    # returns an array of hash containing tags of a host
    def self.find_all_tags_from_host(db_host)
        tags = db_host.connection.select_all("SELECT t.id, t.resource_id, p.name FROM resource_tags as t INNER JOIN resources r ON t.resource_id=r.id INNER JOIN puppet_tags as p ON t.puppet_tag_id=p.id WHERE r.host_id=%s" % db_host.id)
        tags.each do |val|
            val['resource_id'] = Integer(val['resource_id'])
        end
        tags
    end
end
