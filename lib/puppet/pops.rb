module Puppet
  # The Pops language system. This includes the parser, evaluator, AST model, and
  # Binder.
  #
  # @todo Explain how a user should use this to parse and evaluate the puppet
  #   language.
  #
  # @note Warning: Pops is still considered experimental, as such the API may
  #   change at any time.
  #
  # @api public
  module Pops
    require 'semantic'

    require 'puppet/pops/patterns'
    require 'puppet/pops/utils'

    require 'puppet/pops/adaptable'
    require 'puppet/pops/adapters'

    require 'puppet/pops/visitable'
    require 'puppet/pops/visitor'

    require 'puppet/pops/containment'

    require 'puppet/pops/issues'
    require 'puppet/pops/semantic_error'
    require 'puppet/pops/label_provider'
    require 'puppet/pops/validation'
    require 'puppet/pops/issue_reporter'
    require 'puppet/pops/lookup'
    require 'puppet/pops/lookup/interpolation'
    require 'puppet/pops/lookup/invocation'
    require 'puppet/pops/lookup/sub_lookup'
    require 'puppet/pops/lookup/explainer'

    require 'puppet/pops/model/model'

    # (the Types module initializes itself)
    require 'puppet/pops/types/types'
    require 'puppet/pops/types/string_converter'

    require 'puppet/pops/merge_strategy'

    module Model
      require 'puppet/pops/model/tree_dumper'
      require 'puppet/pops/model/ast_transformer'
      require 'puppet/pops/model/factory'
      require 'puppet/pops/model/model_tree_dumper'
      require 'puppet/pops/model/model_label_provider'
    end

    module Binder
      module SchemeHandler
        # the handlers are auto loaded via bindings
      end
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
      require 'puppet/pops/binder/bindings_composer'
      require 'puppet/pops/binder/bindings_model_dumper'
      require 'puppet/pops/binder/system_bindings'
      require 'puppet/pops/binder/bindings_loader'

      module Config
        require 'puppet/pops/binder/config/binder_config'
        require 'puppet/pops/binder/config/binder_config_checker'
        require 'puppet/pops/binder/config/issues'
        require 'puppet/pops/binder/config/diagnostic_producer'
      end
    end

    module Evaluator
      require 'puppet/pops/evaluator/literal_evaluator'
      require 'puppet/pops/evaluator/callable_signature'
      require 'puppet/pops/evaluator/runtime3_converter'
      require 'puppet/pops/evaluator/runtime3_support'
      require 'puppet/pops/evaluator/evaluator_impl'
      require 'puppet/pops/evaluator/epp_evaluator'
      require 'puppet/pops/evaluator/collector_transformer'
      require 'puppet/pops/evaluator/puppet_proc'
      module Collectors
        require 'puppet/pops/evaluator/collectors/abstract_collector'
        require 'puppet/pops/evaluator/collectors/fixed_set_collector'
        require 'puppet/pops/evaluator/collectors/catalog_collector'
        require 'puppet/pops/evaluator/collectors/exported_collector'
      end
    end

    module Parser
      require 'puppet/pops/parser/eparser'
      require 'puppet/pops/parser/parser_support'
      require 'puppet/pops/parser/locator'
      require 'puppet/pops/parser/locatable'
      require 'puppet/pops/parser/lexer2'
      require 'puppet/pops/parser/evaluating_parser'
      require 'puppet/pops/parser/epp_parser'
      require 'puppet/pops/parser/code_merger'
    end

    module Validation
      require 'puppet/pops/validation/checker4_0'
      require 'puppet/pops/validation/validator_factory_4_0'
    end

    # Subsystem for puppet functions defined in ruby.
    #
    # @api public
    module Functions
      require 'puppet/pops/functions/function'
      require 'puppet/pops/functions/dispatch'
      require 'puppet/pops/functions/dispatcher'
    end

    module Migration
      require 'puppet/pops/migration/migration_checker'
    end
  end

  require 'puppet/parser/ast/pops_bridge'
  require 'puppet/bindings'
  require 'puppet/functions'
  require 'puppet/loaders'
end
require 'puppet/plugins/data_providers'
