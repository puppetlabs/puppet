class Puppet::Rails::RailsParameter < ActiveRecord::Base
    belongs_to :rails_resources

    def to_resourceparam(source)
        hash = self.attributes
        hash[:source] = source
        hash.delete("rails_resource_id")
        hash.delete("id")
        Puppet::Parser::Resource::Param.new hash
    end
end

# $Id$
