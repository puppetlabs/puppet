require 'rgen/metamodel_builder'

# The Types model is a model of Puppet Language types.
#
# The exact relationship between types is not visible in this model wrt. the PDataType which is an abstraction
# of Literal, Array[Data], and Hash[Literal, Data] nested to any depth. This means it is not possible to
# infer the type by simply looking at the inheritance hierarchy. The `Puppet::Pops::Types::TypeCalculator` should
# be used to answer questions about types.
#
module Puppet::Pops::Types

  class PType < Puppet::Pops::Model::PopsObject
  end

  class PObjectType < Puppet::Pops::Model::PopsObject
  end

  class PNilType < PObjectType
  end

  class PDataType < PObjectType
  end

  class PLiteralType < PDataType
  end

  class PStringType < PLiteralType
  end

  class PNumericType < PLiteralType
  end

  class PIntegerType < PNumericType
  end

  class PFloatType < PNumericType
  end

  class PPatternType < PLiteralType
  end

  class PBooleanType < PLiteralType
  end

  class PCollectionType < PObjectType
    contains_one_uni 'element_type', PObjectType
  end

  class PArrayType < PCollectionType
  end

  class PHashType < PCollectionType
    contains_one_uni 'key_type', PObjectType
  end

  class PRubyType < PObjectType
    has_attr 'ruby_class', String
  end
end
