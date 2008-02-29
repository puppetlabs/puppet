require 'puppet/rails/resource'
require 'puppet/rails/fact_name'
require 'puppet/rails/source_file'
require 'puppet/util/rails/collection_merger'

# Puppet::TIME_DEBUG = true

class Puppet::Rails::Host < ActiveRecord::Base
    include Puppet::Util
    include Puppet::Util::CollectionMerger

    has_many :fact_values, :dependent => :destroy
    has_many :fact_names, :through => :fact_values
    belongs_to :source_file
    has_many :resources,
        :include => :param_values,
        :dependent => :destroy

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
    def self.store(node, resources)
        args = {}

        host = nil
        transaction do
            #unless host = find_by_name(name)
            seconds = Benchmark.realtime {
                unless host = find_by_name(node.name)
                    host = new(:name => node.name)
                end
            }
            Puppet.notice("Searched for host in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)
            if ip = node.parameters["ipaddress"]
                host.ip = ip
            end

            # Store the facts into the database.
            host.setfacts node.parameters

            seconds = Benchmark.realtime {
                host.setresources(resources)
            }
            Puppet.notice("Handled resources in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)

            host.last_compile = Time.now

            host.save
        end

        return host
    end

    # Return the value of a fact.
    def fact(name)
        if fv = self.fact_values.find(:all, :include => :fact_name,
                                      :conditions => "fact_names.name = '#{name}'") 
            return fv
        else
            return nil
        end
    end
    
    # returns a hash of fact_names.name => [ fact_values ] for this host.
    def get_facts_hash
        fact_values = self.fact_values.find(:all, :include => :fact_name)
        return fact_values.inject({}) do | hash, value |
            hash[value.fact_name.name] ||= []
            hash[value.fact_name.name] << value
            hash
        end
    end
    

    def setfacts(facts)
        facts = facts.dup
        
        ar_hash_merge(get_facts_hash(), facts, 
                      :create => Proc.new { |name, values|
                          fact_name = Puppet::Rails::FactName.find_or_create_by_name(name)
                          values = [values] unless values.is_a?(Array)
                          values.each do |value|
                              fact_values.build(:value => value,
                                                :fact_name => fact_name)
                          end
                      }, :delete => Proc.new { |values|
                          values.each { |value| self.fact_values.delete(value) }
                      }, :modify => Proc.new { |db, mem|
                          mem = [mem].flatten
                          fact_name = db[0].fact_name
                          db_values = db.collect { |fact_value| fact_value.value }
                          (db_values - (db_values & mem)).each do |value|
                              db.find_all { |fact_value| 
                                  fact_value.value == value 
                              }.each { |fact_value|
                                  fact_values.delete(fact_value)
                              }
                          end
                          (mem - (db_values & mem)).each do |value|
                              fact_values.build(:value => value, 
                                                :fact_name => fact_name)
                          end
                      })
    end

    # Set our resources.
    def setresources(list)
        existing = nil
        seconds = Benchmark.realtime {

            # Preload the parameters with the resource query, but not the tags, since doing so makes the query take about 10x longer.
            # I've left the other queries in so that it's straightforward to switch between them for testing, if we so desire.
            #existing = resources.find(:all, :include => [{:param_values => :param_name, :resource_tags => :puppet_tag}, :source_file]).inject({}) do | hash, resource |
            #existing = resources.find(:all, :include => [{:resource_tags => :puppet_tag}, :source_file]).inject({}) do | hash, resource |
            existing = resources.find(:all, :include => [{:param_values => :param_name}, :source_file]).inject({}) do | hash, resource |
                hash[resource.ref] = resource
                hash
            end
        }

        Puppet.notice("Searched for resources in %0.2f seconds" % seconds) if defined?(Puppet::TIME_DEBUG)

        compiled = list.inject({}) do |hash, resource|
            hash[resource.ref] = resource
            hash
        end
        
        ar_hash_merge(existing, compiled,
                      :create => Proc.new { |ref, resource|
                          resource.to_rails(self)
                      }, :delete => Proc.new { |resource|
                          self.resources.delete(resource)
                      }, :modify => Proc.new { |db, mem|
                          mem.modify_rails(db)
                      })
    end

    def update_connect_time
        self.last_connect = Time.now
        save
    end
end

