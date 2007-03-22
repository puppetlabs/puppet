require 'puppet/rails/resource'
require 'puppet/rails/fact_name'
require 'puppet/rails/source_file'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Host < ActiveRecord::Base
    include Puppet::Util
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

        host = nil
        transaction do
            #unless host = find_by_name(name)
            seconds = Benchmark.realtime {
                #unless host = find_by_name(name, :include => {:resources => {:param_names => :param_values}, :fact_names => :fact_values})
                unless host = find_by_name(name)
                    host = new(:name => name)
                end
            }
            Puppet.notice("Searched for host in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)
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
        end

        return host
    end

    def tags=(tags)
        tags.each do |tag|   
            self.tag_with tag
        end
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
        facts = facts.dup
        remove = []

        existing = nil
        seconds = Benchmark.realtime {
            existing = fact_names.find(:all, :include => :fact_values)
        }
        Puppet.debug("Searched for facts in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)

        existing.each do |fn|
            if value = facts[fn.name]
                facts.delete(fn.name)
                fn.fact_values.each do |fv|
                    unless value == fv.value
                        fv.value = value
                    end
                end
            else
                remove << fn
            end
        end

        # Make a new fact for the rest of them
        facts.each do |fact, value|
            fn = fact_names.build(:name => fact)
            fn.fact_values = [fn.fact_values.build(:value => value)]
        end

        # Now remove anything necessary.
        remove.each do |fn|
            fact_names.delete(fn)
        end
    end

    # Set our resources.
    def setresources(list)
        compiled = {}
        remove = []
        existing = nil
        seconds = Benchmark.realtime {
            existing = resources.find(:all, :include => {:param_names => :param_values})
        }
        Puppet.notice("Searched for resources in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)
        list.each do |resource|
            compiled[resource.ref] = resource
        end
        existing.each do |resource|
            if comp = compiled[resource.ref]
                compiled.delete(comp.ref)
                comp.to_rails(self, resource)
            else
                remove << resource
            end
        end

        compiled.each do |name, resource|
            resource.to_rails(self)
        end

        remove.each do |resource|
            resources.delete(resource)
        end
    end

    def update_connect_time
        self.last_connect = Time.now
        save
    end
end

# $Id$
