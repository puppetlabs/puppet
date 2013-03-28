# Require this to require everything in the pops api
module Puppet
  module Pops
    module API
      require 'puppet/pops/api/patterns'
      require 'puppet/pops/api/utils'

      require 'puppet/pops/api/adaptable'
      require 'puppet/pops/api/adapters'

      require 'puppet/pops/api/visitable'
      require 'puppet/pops/api/visitor'

      require 'puppet/pops/api/containment'

      require 'puppet/pops/api/origin'

      require 'puppet/pops/api/issues'
      require 'puppet/pops/api/label_provider'
      require 'puppet/pops/api/validation'

      require 'puppet/pops/api/model/model'
    end
  end
end
