# frozen_string_literal: true

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
    EMPTY_HASH = {}.freeze
    EMPTY_ARRAY = [].freeze
    EMPTY_STRING = ''

    MAX_INTEGER =  0x7fffffffffffffff
    MIN_INTEGER = -0x8000000000000000

    DOUBLE_COLON = '::'
    USCORE = '_'

    require 'semantic_puppet'

    require_relative 'pops/patterns'
    require_relative 'pops/utils'
    require_relative 'pops/puppet_stack'

    require_relative 'pops/adaptable'
    require_relative 'pops/adapters'

    require_relative 'pops/visitable'
    require_relative 'pops/visitor'

    require_relative 'pops/issues'
    require_relative 'pops/semantic_error'
    require_relative 'pops/label_provider'
    require_relative 'pops/validation'
    require_relative 'pops/issue_reporter'

    require_relative 'pops/time/timespan'
    require_relative 'pops/time/timestamp'

    # (the Types module initializes itself)
    require_relative 'pops/types/types'
    require_relative 'pops/types/string_converter'
    require_relative 'pops/lookup'

    require_relative 'pops/merge_strategy'

    module Model
      require_relative 'pops/model/ast'
      require_relative 'pops/model/tree_dumper'
      require_relative 'pops/model/ast_transformer'
      require_relative 'pops/model/factory'
      require_relative 'pops/model/model_tree_dumper'
      require_relative 'pops/model/model_label_provider'
    end

    module Resource
      require_relative 'pops/resource/resource_type_impl'
    end

    module Evaluator
      require_relative 'pops/evaluator/literal_evaluator'
      require_relative 'pops/evaluator/callable_signature'
      require_relative 'pops/evaluator/runtime3_converter'
      require_relative 'pops/evaluator/runtime3_resource_support'
      require_relative 'pops/evaluator/runtime3_support'
      require_relative 'pops/evaluator/evaluator_impl'
      require_relative 'pops/evaluator/epp_evaluator'
      require_relative 'pops/evaluator/collector_transformer'
      require_relative 'pops/evaluator/puppet_proc'
      require_relative 'pops/evaluator/deferred_resolver'
      module Collectors
        require_relative 'pops/evaluator/collectors/abstract_collector'
        require_relative 'pops/evaluator/collectors/fixed_set_collector'
        require_relative 'pops/evaluator/collectors/catalog_collector'
        require_relative 'pops/evaluator/collectors/exported_collector'
      end
    end

    module Parser
      require_relative 'pops/parser/eparser'
      require_relative 'pops/parser/parser_support'
      require_relative 'pops/parser/locator'
      require_relative 'pops/parser/locatable'
      require_relative 'pops/parser/lexer2'
      require_relative 'pops/parser/evaluating_parser'
      require_relative 'pops/parser/epp_parser'
      require_relative 'pops/parser/code_merger'
    end

    module Validation
      require_relative 'pops/validation/checker4_0'
      require_relative 'pops/validation/validator_factory_4_0'
    end

    # Subsystem for puppet functions defined in ruby.
    #
    # @api public
    module Functions
      require_relative 'pops/functions/function'
      require_relative 'pops/functions/dispatch'
      require_relative 'pops/functions/dispatcher'
    end

    module Migration
      require_relative 'pops/migration/migration_checker'
    end

    module Serialization
      require_relative 'pops/serialization'
    end
  end

  require_relative '../puppet/parser/ast/pops_bridge'
  require_relative '../puppet/functions'
  require_relative '../puppet/datatypes'

  Puppet::Pops::Model.register_pcore_types
end
