module RGen

module Serializer

# Filters refereences with an eOpposite:
#  1. containment references are always preferred
#  2. at a 1-to-n reference the 1-reference is always preferred
#  3. otherwise the reference with the name in string sort order before the opposite's name is prefereed
# 
OppositeReferenceFilter = proc do |features|
  features.reject{|f| f.is_a?(RGen::ECore::EReference) && !f.containment && f.eOpposite &&
    (f.eOpposite.containment || (f.many && !f.eOpposite.many) || (!(!f.many && f.eOpposite.many) && (f.name < f.eOpposite.name)))}
end

end

end

