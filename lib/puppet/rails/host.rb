require 'puppet/rails/resource'
require 'puppet/rails/fact_name'
require 'puppet/rails/source_file'
require 'puppet/util/rails/collection_merger'

# Puppet::TIME_DEBUG = true

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
                unless host = find_by_name(name, :include => {:fact_names => :fact_values})
                #unless host = find_by_name(name)
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


            seconds = Benchmark.realtime {
                host.setresources(hash[:resources])
            }
            Puppet.notice("Handled resources in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)

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

        collection_merge :fact_names, :updates => facts, :modify => Proc.new { |fn, name, value|
            fn.fact_values.each do |fv|
                unless value == fv.value
                    fv.value = value
                end
                break
            end
        }, :create => Proc.new { |name, value|
            fn = fact_names.build(:name => name)
            fn.fact_values = [fn.fact_values.build(:value => value)]
        }
    end

    # Set our resources.
    def setresources(list)
        compiled = {}
        remove = []
        existing = nil
        seconds = Benchmark.realtime {
            #existing = resources.find(:all)
            existing = resources.find(:all, :include => {:param_names => :param_values})
            #existing = resources
        }
        Puppet.notice("Searched for resources in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)
        list.each do |resource|
            compiled[resource.ref] = resource
        end

        collection_merge :resources, :existing => existing, :updates => compiled
    end

    def update_connect_time
        self.last_connect = Time.now
        save
    end
end

# $Id$
