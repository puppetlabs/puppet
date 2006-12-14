class Puppet::Rails::ParamName < ActiveRecord::Base
    has_many :param_values
    belongs_to :resources

    def to_resourceparam(source)
        hash = {}
        hash[:name] = self.name.to_sym
        hash[:source] = source
        hash[:value] = self.param_values.find(:first).value
        Puppet::Parser::Resource::Param.new hash
    end
end

