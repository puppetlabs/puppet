module Puppet
  module Pops
    require 'puppet/pops/patterns'
    require 'puppet/pops/utils'

    require 'puppet/pops/adaptable'
    require 'puppet/pops/adapters'

    require 'puppet/pops/visitable'
    require 'puppet/pops/visitor'

    require 'puppet/pops/containment'

    require 'puppet/pops/issues'
    require 'puppet/pops/label_provider'
    require 'puppet/pops/validation'

    require 'puppet/pops/model/model'

    module Model
      require 'puppet/pops/model/tree_dumper'
      require 'puppet/pops/model/ast_transformer'
      require 'puppet/pops/model/ast_tree_dumper'
      require 'puppet/pops/model/factory'
      require 'puppet/pops/model/model_tree_dumper'
      require 'puppet/pops/model/model_label_provider'
    end

    module Parser
      require 'puppet/pops/parser/eparser'
      require 'puppet/pops/parser/parser_support'
      require 'puppet/pops/parser/lexer'
    end

    module Validation
      require 'puppet/pops/validation/checker3_1'
      require 'puppet/pops/validation/validator_factory_3_1'
    end
  end
end
