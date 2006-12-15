require 'puppet/rails/resource'

class Puppet::Rails::Host < ActiveRecord::Base
    has_many :fact_values, :through => :fact_names 
    has_many :fact_names
    belongs_to :puppet_classes
    has_many :source_files
    has_many :resources, :include => [ :param_names, :param_values ]

    acts_as_taggable

    def facts(name)
        fv = self.fact_values.find(:first, :conditions => "fact_names.name = '#{name}'") 
        return fv.value
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
        host = nil
        Puppet::Util.benchmark(:info, "Found/created host") do
            host = self.find_or_create_by_name(hash[:facts]["hostname"], args)
        end

        hash[:facts].each do |name, value|
            fn = host.fact_names.find_or_create_by_name(name)
            fv = fn.fact_values.find_or_create_by_value(value)
            host.fact_names << fn
        end

        unless hash[:resources]
            raise ArgumentError, "You must pass resources"
        end

        typenames = []
        Puppet::Type.loadall
        Puppet::Type.eachtype do |type|
            typenames << type.name.to_s
        end

        Puppet::Util.benchmark(:info, "Converted resources") do
            hash[:resources].each do |resource|
                resargs = resource.to_hash.stringify_keys


                if typenames.include?(resource.type)
                    rtype = "Puppet#{resource.type.to_s.capitalize}"
                end

                res = host.resources.create(:title => resource[:title], :type => rtype)
                res.save
                resargs.each do |param, value|
                    pn = res.param_names.find_or_create_by_name(param)
                    pv = pn.param_values.find_or_create_by_value(value)
                    res.param_names << pn
                end
            end
        end

        Puppet::Util.benchmark(:info, "Saved host to database") do
            host.save
        end

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
