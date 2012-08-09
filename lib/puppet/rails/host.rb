require 'puppet/node/environment'
require 'puppet/rails'
require 'puppet/rails/resource'
require 'puppet/rails/fact_name'
require 'puppet/rails/source_file'
require 'puppet/rails/benchmark'
require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Host < ActiveRecord::Base
  include Puppet::Rails::Benchmark
  extend Puppet::Rails::Benchmark
  include Puppet::Util
  include Puppet::Util::CollectionMerger

  has_many :fact_values, :dependent => :destroy, :class_name => "Puppet::Rails::FactValue"
  has_many :fact_names, :through => :fact_values, :class_name => "Puppet::Rails::FactName"
  belongs_to :source_file
  has_many :resources, :dependent => :destroy, :class_name => "Puppet::Rails::Resource"

  def self.from_puppet(node)
    host = find_by_name(node.name) || new(:name => node.name)

    {"ipaddress" => "ip", "environment" => "environment"}.each do |myparam, itsparam|
      if value = node.send(myparam)
        host.send(itsparam + "=", value)
      end
    end

    host
  end

  # Override the setter for environment to force it to be a string, lest it
  # be YAML encoded.  See #4487.
  def environment=(value)
    super value.to_s
  end

  # returns a hash of fact_names.name => [ fact_values ] for this host.
  # Note that 'fact_values' is actually a list of the value instances, not
  # just actual values.
  def get_facts_hash
    fact_values = self.fact_values.find(:all, :include => :fact_name)
    return fact_values.inject({}) do | hash, value |
      hash[value.fact_name.name] ||= []
      hash[value.fact_name.name] << value
      hash
    end
  end


  # This is *very* similar to the merge_parameters method
  # of Puppet::Rails::Resource.
  def merge_facts(facts)
    # symbol key handling is not good, but works as long keys don't conflict, i.e. for all keys a, b: a.to_s != b.to_s
    db_facts = {}

    deletions = []
    self.fact_values.find(:all, :include => :fact_name).each do |value|
      name = value.fact_name.name
      Puppet.debug "Found db fact: #{name} = #{value.value.inspect}"
      unless facts.include?(name) or facts.include?(name.to_sym)
        deletions << value['id']
        Puppet.debug "Deleting fact, not present anymore: #{name}"
        next
      end
      # Now store them for later testing.
      db_facts[name] ||= []
      db_facts[name] << value
    end

    # Update single facts directly.
    # For list of values clear the old list and readd the new list if the list is different.
    # TODO: sort lists before comparing them? database returns them in random order...
    db_facts.each do |name, value_hashes|
      values = value_hashes.collect { |v| v['value'] }
      value = facts.include?(name) ? facts[name] : facts[name.to_sym]
      value = value.is_a?(Array) ? value : [value]

      unless values == value
        if (values.length == 1 and value.length == 1)
          Puppet.debug "Updating single fact: #{name} = #{value[0].inspect}"
          value_hashes[0].value= value[0]
          value_hashes[0].save!
        else
          Puppet.debug "Delete changing multi fact: #{name}"
          db_facts.delete(name) # we have to re add it below
          value_hashes.each { |v| deletions << v['id'] }
        end
      end
    end

    # Perform our deletions.
    Puppet::Rails::FactValue.delete(deletions) unless deletions.empty?

    # Lastly, add any new parameters.
    facts.each do |name, value|
      next if db_facts.include?(name.to_s)
      Puppet.debug "Adding fact: #{name} = #{value.inspect}"
      values = value.is_a?(Array) ? value : [value]

      values.each do |v|
        fact_values.build(:value => v, :fact_name => Puppet::Rails::FactName.find_or_create_by_name(name.to_s))
      end
    end
  end

  # Set our resources.
  def merge_resources(list)
    # keep only exported resources in thin_storeconfig mode
    list = list.select { |r| r.exported? } if Puppet.settings[:thin_storeconfigs]

    resources_by_id = nil
    debug_benchmark("Searched for resources") {
      resources_by_id = find_resources
    }

    debug_benchmark("Searched for resource params and tags") {
      find_resources_parameters_tags(resources_by_id)
    } if id

    debug_benchmark("Performed resource comparison") {
      compare_to_catalog(resources_by_id, list)
    }
  end

  def find_resources
    condition = { :exported => true } if Puppet.settings[:thin_storeconfigs]

    resources.find(:all, :include => :source_file, :conditions => condition || {}).inject({}) do | hash, resource |
      hash[resource.id] = resource
      hash
    end
  end

  def find_resources_parameters_tags(resources)
    find_resources_parameters(resources)
    find_resources_tags(resources)
  end

  def compare_to_catalog(existing, list)
    compiled = list.inject({}) do |hash, resource|
      hash[resource.ref] = resource
      hash
    end

    resources = nil
    debug_benchmark("Resource removal") {
      resources = remove_unneeded_resources(compiled, existing)
    }

    # Now for all resources in the catalog but not in the db, we're pretty easy.
    additions = nil
    debug_benchmark("Resource merger") {
      additions = perform_resource_merger(compiled, resources)
    }

    debug_benchmark("Resource addition") {
      additions.each do |resource|
        build_rails_resource_from_parser_resource(resource)
      end

      log_accumulated_marks "Added resources"
    }
  end

  def add_new_resources(additions)
    additions.each do |resource|
      Puppet::Rails::Resource.from_parser_resource(self, resource)
    end
  end

  # Turn a parser resource into a Rails resource.
  def build_rails_resource_from_parser_resource(resource)
    db_resource = nil
    accumulate_benchmark("Added resources", :initialization) {
      args = Puppet::Rails::Resource.rails_resource_initial_args(resource)

      db_resource = self.resources.build(args)

      # Our file= method does the name to id conversion.
      db_resource.file = resource.file
    }


    accumulate_benchmark("Added resources", :parameters) {
      resource.each do |param, value|
        Puppet::Rails::ParamValue.from_parser_param(param, value).each do |value_hash|
          db_resource.param_values.build(value_hash)
        end
      end
    }

    accumulate_benchmark("Added resources", :tags) {
      resource.tags.each { |tag| db_resource.add_resource_tag(tag) }
    }

    db_resource.save

    db_resource
  end


  def perform_resource_merger(compiled, resources)
    return compiled.values if resources.empty?

    # Now for all resources in the catalog but not in the db, we're pretty easy.
    additions = []
    compiled.each do |ref, resource|
      if db_resource = resources[ref]
        db_resource.merge_parser_resource(resource)
      else
        additions << resource
      end
    end
    log_accumulated_marks "Resource merger"

    additions
  end

  def remove_unneeded_resources(compiled, existing)
    deletions = []
    resources = {}
    existing.each do |id, resource|
      # it seems that it can happen (see bug #2010) some resources are duplicated in the
      # database (ie logically corrupted database), in which case we remove the extraneous
      # entries.
      if resources.include?(resource.ref)
        deletions << id
        next
      end

      # If the resource is in the db but not in the catalog, mark it
      # for removal.
      unless compiled.include?(resource.ref)
        deletions << id
        next
      end

      resources[resource.ref] = resource
    end
    # We need to use 'destroy' here, not 'delete', so that all
    # dependent objects get removed, too.
    Puppet::Rails::Resource.destroy(deletions) unless deletions.empty?

    resources
  end

  def find_resources_parameters(resources)
    params = Puppet::Rails::ParamValue.find_all_params_from_host(self)

    # assign each loaded parameters/tags to the resource it belongs to
    params.each do |param|
      resources[param['resource_id']].add_param_to_list(param) if resources.include?(param['resource_id'])
    end
  end

  def find_resources_tags(resources)
    tags = Puppet::Rails::ResourceTag.find_all_tags_from_host(self)

    tags.each do |tag|
      resources[tag['resource_id']].add_tag_to_list(tag) if resources.include?(tag['resource_id'])
    end
  end

  def to_puppet
    node = Puppet::Node.new(self.name)
    {"ip" => "ipaddress", "environment" => "environment"}.each do |myparam, itsparam|
      if value = send(myparam)
        node.send(itsparam + "=", value)
      end
    end

    node
  end
end
