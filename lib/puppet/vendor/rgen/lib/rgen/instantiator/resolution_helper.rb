module RGen
module Instantiator

module ResolutionHelper

# sets the target of an unresolved reference in the model
# returns :type_error if the target is of wrong type, otherwise :success
#
def self.set_uref_target(uref, target)
  refs = uref.element.getGeneric(uref.feature_name)
  if refs.is_a?(Array) 
    index = refs.index(uref.proxy)
    uref.element.removeGeneric(uref.feature_name, uref.proxy)
    begin
      uref.element.addGeneric(uref.feature_name, target, index)
    rescue StandardError => e
      if is_type_error?(e)
        uref.element.addGeneric(uref.feature_name, uref.proxy, index)
        return :type_error
      else
        raise
      end
    end
  else
    begin
      # this will replace the proxy
      uref.element.setGeneric(uref.feature_name, target)
    rescue StandardError => e
      if is_type_error?(e)
        return :type_error
      else
        raise
      end
    end
  end
  :success
end

def self.is_type_error?(e)
  e.message =~ /Can not use a .* where a .* is expected/
end

end

end
end

