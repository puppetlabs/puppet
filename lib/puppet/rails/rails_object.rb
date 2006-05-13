require 'puppet'
require 'puppet/rails/rails_parameter'

RailsParameter = Puppet::Rails::RailsParameter
class Puppet::Rails::RailsObject < ActiveRecord::Base
    has_many :rails_parameters, :dependent => :delete_all
    serialize :tags, Array

    belongs_to :host

    # Add a set of parameters.
    def addparams(params)
        params.each do |pname, pvalue|
            pobj = RailsParameter.new(
                :name => pname,
                :value => pvalue
            )

            self.rails_parameters << pobj
        end
    end

    # Convert our object to a trans_object
    def to_trans
        obj = Puppet::TransObject.new(name(), ptype())

        [:file, :line, :tags].each do |method|
            if val = send(method)
                obj.send(method.to_s + "=", val)
            end
        end
        params.each do |name, value|
            obj[name] = value
        end

        return obj
    end
end

# $Id$
