require 'puppet/rails/resource'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Host < ActiveRecord::Base
    include Puppet::Util::CollectionMerger

    has_many :fact_values, :through => :fact_names 
    has_many :fact_names, :dependent => :destroy
    belongs_to :puppet_classes
    has_many :source_files
    has_many :resources,
        :include => [ :param_names, :param_values ],
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

        host.save

        return host
    end

    # Return the value of a fact.
    def fact(name)
        if fv = self.fact_values.find(:first, :conditions => "fact_names.name = '#{name}'") 
            return fv.value
        else
            return nil
        end
    end

    def setfacts(facts)
        collection_merge(:fact_names, facts) do |name, value|
            fn = fact_names.find_by_name(name) || fact_names.build(:name => name)
            # We're only ever going to have one fact value, at this point.
            unless fv = fn.fact_values.find_by_value(value)
                fv = fn.fact_values.build(:value => value)
            end
            fn.fact_values = [fv]

            fn
        end
    end

    # Set our resources.
    def setresources(list)
        collection_merge(:resources, list) do |resource|
            resource.to_rails(self)
        end
    end
end

# $Id$
