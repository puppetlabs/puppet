require 'puppet/rails/rails_resource'

#RailsObject = Puppet::Rails::RailsObject
class Puppet::Rails::Host < ActiveRecord::Base
    serialize :facts, Hash
    serialize :classes, Array

    has_many :rails_resources, :dependent => :delete_all,
             :include => :rails_parameters

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
        [:name, :facts, :classes].each do |param|
            if hash[param]
                args[param] = hash[param]
            end
        end

        if hash[:facts].include?("ipaddress")
            args[:ip] = hash[:facts]["ipaddress"]
        end

        unless hash[:resources]
            raise ArgumentError, "You must pass resources"
        end

        if host = self.find_by_name(hash[:name])
            args.each do |param, value|
                unless host[param] == args[param]
                    host[param] = args[param]
                end
            end
        else
            # Create it anew
            host = self.new(args)
        end

        hash[:resources].each do |res|
            res.store(host)
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
