class Puppet::Rails::ParamValue < ActiveRecord::Base
    belongs_to :param_name
    belongs_to :resource
end

# $Id$
