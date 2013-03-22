# Some handy extensions to the UML13 metamodel
# 
module UML13
  
  module AssociationEnd::ClassModule
    def otherEnd
      association.connection.find{|c| c != self}
    end
  end
  
  module Classifier::ClassModule
    def localCompositeEnd
      associationEnd.select{|e| e.aggregation == :composite}
    end
    def remoteCompositeEnd
      associationEnd.otherEnd.select{|e| e.aggregation == :composite}
    end
    def localNavigableEnd
      associationEnd.select{|e| e.isNavigable}
    end
    def remoteNavigableEnd
      associationEnd.otherEnd.select{|e| e.isNavigable}
    end
  end

end
