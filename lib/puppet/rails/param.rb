require 'puppet/util/rails/collection_merger'

class Puppet::Rails::Param < ActiveRecord::Base
    include Puppet::Util::CollectionMerger
    belongs_to :resource

    def to_resourceparam(source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = self.value
        if hash[:value].length == 1
            hash[:value] = hash[:value].shift
        end
        if hash[:value].empty?
            hash[:value] = nil
        end
        Puppet::Parser::Resource::Param.new hash
    end
end

