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

    module Types
      require 'puppet/pops/types/types'
      require 'puppet/pops/types/type_calculator'
      require 'puppet/pops/types/type_factory'
      require 'puppet/pops/types/class_loader'
    end

    module Model
      require 'puppet/pops/model/tree_dumper'
      require 'puppet/pops/model/ast_transformer'
      require 'puppet/pops/model/ast_tree_dumper'
      require 'puppet/pops/model/factory'
      require 'puppet/pops/model/model_tree_dumper'
      require 'puppet/pops/model/model_label_provider'
    end

    module Binder
      module Producers
        require 'puppet/pops/binder/producers'
      end

      require 'puppet/pops/binder/binder'
      require 'puppet/pops/binder/bindings_model'
      require 'puppet/pops/binder/binder_issues'
      require 'puppet/pops/binder/bindings_checker'
      require 'puppet/pops/binder/bindings_factory'
      require 'puppet/pops/binder/bindings_label_provider'
      require 'puppet/pops/binder/bindings_validator_factory'
      require 'puppet/pops/binder/injector_entry'
      require 'puppet/pops/binder/key_factory'
      require 'puppet/pops/binder/injector'
      require 'puppet/pops/binder/hiera2'
      require 'puppet/pops/binder/bindings_composer'
      require 'puppet/pops/binder/bindings_model_dumper'
      require 'puppet/pops/binder/system_bindings'

      module Config
        require 'puppet/pops/binder/config/binder_config'
        require 'puppet/pops/binder/config/binder_config_checker'
        require 'puppet/pops/binder/config/issues'
        require 'puppet/pops/binder/config/diagnostic_producer'
      end
    end

    module Parser
      require 'puppet/pops/parser/eparser'
      require 'puppet/pops/parser/parser_support'
      require 'puppet/pops/parser/lexer'
      require 'puppet/pops/parser/evaluating_parser'
    end

    module Validation
      require 'puppet/pops/validation/checker3_1'
      require 'puppet/pops/validation/validator_factory_3_1'
    end
  end
end
