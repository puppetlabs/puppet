require 'puppet/util/rails/reference_serializer'

class Puppet::Rails::ParamValue < ActiveRecord::Base
    include Puppet::Util::ReferenceSerializer
    extend Puppet::Util::ReferenceSerializer

    belongs_to :param_name
    belongs_to :resource

    # Store a new parameter in a Rails db.
    def self.from_parser_param(param, values)
        values = munge_parser_values(values)

        param_name = Puppet::Rails::ParamName.find_or_create_by_name(param.to_s)
        return values.collect do |v|
            {:value => v, :param_name => param_name}
        end
    end

    # Make sure an array (or possibly not an array) of values is correctly
    # set up for Rails.  The main thing is that Resource::Reference objects
    # should stay objects, so they just get serialized.
    def self.munge_parser_values(value)
        values = value.is_a?(Array) ? value : [value]
        values.map do |v|
            if v.is_a?(Puppet::Resource::Reference)
                v
            else
                v.to_s
            end
        end
    end


    def value
        unserialize_value(self[:value])
    end

    # I could not find a cleaner way to handle making sure that resource references
    # were consistently serialized and deserialized.
    def value=(val)
        self[:value] = serialize_value(val)
    end

    def to_label
        "#{self.param_name.name}"
    end

    # returns an array of hash containing all the parameters of a given resource
    def self.find_all_params_from_resource(db_resource)
        params = db_resource.connection.select_all("SELECT v.id, v.value, v.line, v.resource_id, v.param_name_id, n.name FROM param_values as v INNER JOIN param_names as n ON v.param_name_id=n.id WHERE v.resource_id=%s" % db_resource.id)
        params.each do |val|
            val['value'] = unserialize_value(val['value'])
            val['line'] = val['line'] ? Integer(val['line']) : nil
            val['resource_id'] = Integer(val['resource_id'])
        end
        params
    end

    # returns an array of hash containing all the parameters of a given host
    def self.find_all_params_from_host(db_host)
        params = db_host.connection.select_all("SELECT v.id, v.value,  v.line, v.resource_id, v.param_name_id, n.name FROM param_values as v INNER JOIN resources r ON v.resource_id=r.id INNER JOIN param_names as n ON v.param_name_id=n.id WHERE r.host_id=%s" % db_host.id)
        params.each do |val|
            val['value'] = unserialize_value(val['value'])
            val['line'] = val['line'] ? Integer(val['line']) : nil
            val['resource_id'] = Integer(val['resource_id'])
        end
        params
    end

    def to_s
        "%s => %s" % [self.name, self.value]
    end
end
