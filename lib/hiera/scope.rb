class Hiera
  class Scope
    CALLING_CLASS = "calling_class"
    CALLING_MODULE = "calling_module"
    MODULE_NAME = "module_name"

    attr_reader :real

    def initialize(real)
      @real = real
    end

    def [](key)
      if key == CALLING_CLASS
        ans = find_hostclass(@real)
      elsif key == CALLING_MODULE
        ans = @real.lookupvar(MODULE_NAME)
      else
        ans = @real.lookupvar(key)
      end

      if ans.nil? or ans == ""
        nil
      else
        ans
      end
    end

    def include?(key)
      if key == CALLING_CLASS or key == CALLING_MODULE
        true
      else
        @real.lookupvar(key) != ""
      end
    end

    def catalog
      @real.catalog
    end

    def resource
      @real.resource
    end

    def compiler
      @real.compiler
    end

    def find_hostclass(scope)
      if scope.source and scope.source.type == :hostclass
        return scope.source.name.downcase
      elsif scope.parent
        return find_hostclass(scope.parent)
      else
        return nil
      end
    end
    private :find_hostclass
  end
end
