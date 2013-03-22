module UML13EA
  class << self
    attr_accessor :idStore
  end
  module ModelElement::ClassModule
    def qualifiedName
      _name = (respond_to?(:_name) ? self._name : name) || "unnamed"
      _namespace = respond_to?(:_namespace) ? self._namespace : namespace
      _namespace && _namespace.qualifiedName ? _namespace.qualifiedName+"::"+_name : _name
    end
  end
  module XmiIdProvider::ClassModule
    def _xmi_id
      UML13EA.idStore.idHash[qualifiedName] ||= "EAID_"+object_id.to_s
    end
  end
  module Package::ClassModule
    def _xmi_id
      UML13EA.idStore.idHash[qualifiedName] ||= "EAPK_"+object_id.to_s
    end
  end
  module Generalization::ClassModule
    def _name
      "#{subtype.name}_#{supertype.name}"
    end
  end
  module Association::ClassModule
    def _name
      connection.collect{|c| "#{c.getType.name}_#{c.name}"}.sort.join("_")
    end
  end
  module AssociationEnd::ClassModule
    def _name
      "#{getType.name}_#{name}"
    end
    def _namespace
      association
    end
  end
  module StateVertex::ClassModule
    def _namespace
      container
    end
  end
end
