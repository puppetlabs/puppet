class Puppet::Rails::ParamName < ActiveRecord::Base
    has_many :param_values, :dependent => :destroy
    belongs_to :resource

    def to_resourceparam(source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = self.param_values.find(:all).collect { |v| v.value }
        if hash[:value].empty?
            hash[:value] = nil
        end
        Puppet::Parser::Resource::Param.new hash
    end
end

# $Id$
