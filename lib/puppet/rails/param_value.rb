require 'puppet/util/rails/reference_serializer'

class Puppet::Rails::ParamValue < ActiveRecord::Base
    include Puppet::Util::ReferenceSerializer
    extend Puppet::Util::ReferenceSerializer

    belongs_to :param_name
    belongs_to :resource

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

end

