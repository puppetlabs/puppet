require 'puppet/pops/api'

module Puppet
  module Pops
    module Impl
      module Model
        require 'puppet/pops/impl/model/tree_dumper'
        require 'puppet/pops/impl/model/ast_transformer'
        require 'puppet/pops/impl/model/ast_tree_dumper'
        require 'puppet/pops/impl/model/factory'
        require 'puppet/pops/impl/model/model_tree_dumper'
        require 'puppet/pops/impl/model/model_label_provider'
      end

      module Parser
        require 'puppet/pops/impl/parser/eparser'
        require 'puppet/pops/impl/parser/parser_support'
        require 'puppet/pops/impl/parser/lexer'
      end

      module Validation
        require 'puppet/pops/impl/validation/checker3_1'
        require 'puppet/pops/impl/validation/validator_factory_3_1'
      end

      # Unfinished
      # require 'puppet/pops/impl/type_creator'

      require 'puppet/pops/impl/base_scope'
      require 'puppet/pops/impl/local_scope'
      require 'puppet/pops/impl/match_scope'
      require 'puppet/pops/impl/named_scope'
      require 'puppet/pops/impl/object_scope'
      require 'puppet/pops/impl/top_scope'

      require 'puppet/pops/impl/evaluator_impl'
      require 'puppet/pops/impl/call_operator'
      require 'puppet/pops/impl/compare_operator'

      # Unfinished
      # module Loader
      #   require 'puppet/pops/impl/loader/base_loader'
      #   require 'puppet/pops/impl/loader/module_loader'
      #   require 'puppet/pops/impl/loader/module_loader_configurator'
      #   require 'puppet/pops/impl/loader/static_loader'
      #   require 'puppet/pops/impl/loader/system_loader'
      #   require 'puppet/pops/impl/loader/uri_helper'
      # end
    end
  end
end
