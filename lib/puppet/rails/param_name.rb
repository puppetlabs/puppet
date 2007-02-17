require 'puppet/util/rails/collection_merger'
require 'puppet/rails/param_value'

class Puppet::Rails::ParamName < ActiveRecord::Base
    include Puppet::Util::CollectionMerger
    has_many :param_values, :dependent => :destroy 
#        def <<(value)
#            ParamValue.with_scope(:create => {:value => value})
#        end
##    end
    belongs_to :resource

    def to_resourceparam(source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = self.param_values.find(:all).collect { |v| v.value }
        if hash[:value].length == 1
            hash[:value] = hash[:value].shift
        end
        if hash[:value].empty?
            hash[:value] = nil
        end
        Puppet::Parser::Resource::Param.new hash
    end
end

# $Id$
