module RGen
  
module ECore
  
module ECoreBuilderMethods
  def eAttr(name, type, argHash={}, &block)
    eAttribute(name, {:eType => type}.merge(argHash), &block)
  end
  
  def eRef(name, type, argHash={}, &block)
    eReference(name, {:eType => type}.merge(argHash), &block)
  end
  
  # create bidirectional reference at once
  def eBiRef(name, type, oppositeName, argHash={})
    raise BuilderError.new("eOpposite attribute not allowed for bidirectional references") \
      if argHash[:eOpposite] || argHash[:opposite_eOpposite]
    eReference(name, {:eType => type}.merge(argHash.reject{|k,v| k.to_s =~ /^opposite_/})) do 
      eReference oppositeName, {:eContainingClass => type, :eType => _context(2),
        :as => :eOpposite, :eOpposite => _context(1)}.
          merge(Hash[*(argHash.select{|k,v| k.to_s =~ /^opposite_/}.
            collect{|p| [p[0].to_s.sub(/^opposite_/,"").to_sym, p[1]]}.flatten)])
    end
  end
  
  # reference shortcuts
  
  alias references_1 eRef
  alias references_one eRef
  
  def references_N(name, type, argHash={})
    eRef(name, type, {:upperBound => -1}.merge(argHash))
  end
  alias references_many references_N
  
  def references_1to1(name, type, oppositeName, argHash={})
    eBiRef(name, type, oppositeName, {:upperBound => 1, :opposite_upperBound => 1}.merge(argHash))
  end
  alias references_one_to_one references_1to1
  
  def references_1toN(name, type, oppositeName, argHash={})
    eBiRef(name, type, oppositeName, {:upperBound => -1, :opposite_upperBound => 1}.merge(argHash))
  end
  alias references_one_to_many references_1toN
  
  def references_Nto1(name, type, oppositeName, argHash={})
    eBiRef(name, type, oppositeName, {:upperBound => 1, :opposite_upperBound => -1}.merge(argHash))
  end
  alias references_many_to_one references_Nto1
  
  def references_MtoN(name, type, oppositeName, argHash={})
    eBiRef(name, type, oppositeName, {:upperBound => -1, :opposite_upperBound => -1}.merge(argHash))
  end
  alias references_many_to_many references_MtoN
  
  # containment reference shortcuts
  
  def contains_1(name, type, argHash={})
    references_1(name, type, {:containment => true}.merge(argHash))  
  end
  alias contains_one contains_1
  
  def contains_N(name, type, argHash={})
    references_N(name, type, {:containment => true}.merge(argHash))  
  end
  alias contains_many contains_N
  
  def contains_1to1(name, type, oppositeName, argHash={})
    references_1to1(name, type, oppositeName, {:containment => true}.merge(argHash))  
  end
  alias contains_one_to_one contains_1to1
  
  def contains_1toN(name, type, oppositeName, argHash={})
    references_1toN(name, type, oppositeName, {:containment => true}.merge(argHash))  
  end
  alias contains_one_to_many contains_1toN  
end

end

end