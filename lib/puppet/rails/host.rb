require 'puppet/rails/resource'
require 'puppet/rails/fact'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Host < ActiveRecord::Base
    include Puppet::Util::CollectionMerger

    has_many :facts
    belongs_to :puppet_classes
    has_many :source_files
    has_many :resources,
        :include => [ :params ],
        :dependent => :destroy

    acts_as_taggable

    # If the host already exists, get rid of its objects
    def self.clean(host)
        if obj = self.find_by_name(host)
            obj.rails_objects.clear
            return obj
        else
            return nil
        end
    end

    # Store our host in the database.
    def self.store(hash)
        unless name = hash[:name]
            raise ArgumentError, "You must specify the hostname for storage"
        end

        args = {}

        unless host = find_by_name(name)
            host = new(:name => name)
        end
        if ip = hash[:facts]["ipaddress"]
            host.ip = ip
        end

        # Store the facts into the database.
        host.setfacts(hash[:facts])

        unless hash[:resources]
            raise ArgumentError, "You must pass resources"
        end

        host.setresources(hash[:resources])

        host.last_compile = Time.now

        host.save

        return host
    end

    def tags=(tags)
        tags.each do |tag|   
            self.tag_with tag
        end
    end

    # Return the value of a fact.
    def fact(name)
        if f = self.facts.find_by_name(name)
            return f.value
        else
            return nil
        end
    end

    def setfacts(facts)
        collection_merge(:facts, facts) do |name, value|
            f = self.facts.find_by_name(name) || self.facts.build(:name => name, :value => value)
            # We're only ever going to have one fact value, at this point.
            f
        end
    end

    # Set our resources.
    def setresources(list)
        collection_merge(:resources, list) do |resource|
            resource.to_rails(self)
        end
    end

    def update_connect_time
        self.last_connect = Time.now
        save
    end
end

# $Id$
