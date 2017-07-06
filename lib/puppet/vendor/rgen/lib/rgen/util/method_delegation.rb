module RGen

module Util
  
module MethodDelegation

class << self
  
  def registerDelegate(delegate, object, method)
    method = method.to_sym
    createDelegateStore(object)
    if object._methodDelegates[method]
      object._methodDelegates[method] << delegate
    else
      object._methodDelegates[method] = [delegate]
      createDelegatingMethod(object, method)
    end
  end
  
  def unregisterDelegate(delegate, object, method)
    method = method.to_sym
    return unless object.respond_to?(:_methodDelegates)
    return unless object._methodDelegates[method]
    object._methodDelegates[method].delete(delegate)
    if object._methodDelegates[method].empty?
      object._methodDelegates[method] = nil
      removeDelegatingMethod(object, method)
      removeDelegateStore(object)
    end
  end

  private
  
  def createDelegateStore(object)
    return if object.respond_to?(:_methodDelegates)
    class << object
      def _methodDelegates
        @_methodDelegates ||= {}
      end
    end
  end
  
  def removeDelegateStore(object)
    return unless object.respond_to?(:_methodDelegates)
    class << object
      remove_method(:_methodDelegates)
    end
  end
  
  def createDelegatingMethod(object, method)
    if hasMethod(object, method)
      object.instance_eval <<-END
        class << self
          alias #{aliasMethodName(method)} #{method}
        end
      END
    end
    
    # define the delegating method
    object.instance_eval <<-END
      class << self
        def #{method}(*args, &block)
          @_methodDelegates[:#{method}].each do |d|
            catch(:continue) do
              return d.#{method}_delegated(self, *args, &block)
            end
          end
          # if aliased method does not exist, we want an exception
          #{aliasMethodName(method)}(*args, &block)
        end
      end
    END
  end

  def removeDelegatingMethod(object, method)
    if hasMethod(object, aliasMethodName(method))
      # there is an aliased original, restore it
      object.instance_eval <<-END
        class << self
          alias #{method} #{aliasMethodName(method)}
          remove_method(:#{aliasMethodName(method)})
        end
      END
    else
      # just delete the delegating method
      object.instance_eval <<-END
        class << self
          remove_method(:#{method})
        end
      END
    end
  end
  
  def hasMethod(object, method)
    # in Ruby 1.9, #methods returns symbols
    if object.methods.first.is_a?(Symbol)
      method = method.to_sym
    else
      method = method.to_s
    end
    object.methods.include?(method)
  end

  def aliasMethodName(method)
    "#{method}_delegate_original"
  end    
end

end

end

end

