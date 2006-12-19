require 'puppet/rails/resource'

class Puppet::Rails::Host < ActiveRecord::Base
    has_many :fact_values, :through => :fact_names 
    has_many :fact_names, :dependent => :destroy
    belongs_to :puppet_classes
    has_many :source_files
    has_many :resources,
        :include => [ :param_names, :param_values ],
        :dependent => :destroy

    acts_as_taggable

    def facts(name)
        if fv = self.fact_values.find(:first, :conditions => "fact_names.name = '#{name}'") 
            return fv.value
        else
            return nil
        end
    end

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
        unless hash[:name]
            raise ArgumentError, "You must specify the hostname for storage"
        end

        args = {}

        if hash[:facts].include?("ipaddress")
            args[:ip] = hash[:facts]["ipaddress"]
        end
        unless host = find_by_name(hash[:facts]["hostname"])
            host = new(:name => hash[:facts]["hostname"])
        end

        # Store the facts into the 
        hash[:facts].each do |name, value|
            fn = host.fact_names.find_by_name(name) || host.fact_names.build(:name => name)
            unless fn.fact_values.find_by_value(value)
                fn.fact_values.build(:value => value)
            end
        end

        unless hash[:resources]
            raise ArgumentError, "You must pass resources"
        end

        resources = []
        hash[:resources].each do |resource|
            resources << resource.to_rails(host)
        end

        host.save

        return host
    end

    # Add all of our RailsObjects
    def addobjects(objects)
        objects.each do |tobj|
            params = {}
            tobj.each do |p,v| params[p] = v end

            args = {:ptype => tobj.type, :name => tobj.name}
            [:tags, :file, :line].each do |param|
                if val = tobj.send(param)
                    args[param] = val
                end
            end

            robj = rails_objects.build(args)

            robj.addparams(params)
            if tobj.collectable
                robj.toggle(:collectable)
            end
        end
    end
end

# $Id$
