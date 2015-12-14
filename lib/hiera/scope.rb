class Hiera
  class Scope
    CALLING_CLASS = "calling_class"
    CALLING_CLASS_PATH = "calling_class_path"
    CALLING_MODULE = "calling_module"
    MODULE_NAME = "module_name"

    attr_reader :real

    def initialize(real)
      @real = real
    end

    def [](key)
      if key == CALLING_CLASS
        ans = find_hostclass(@real)
      elsif key == CALLING_CLASS_PATH
        ans = find_hostclass(@real).gsub(/::/, '/')
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
      if [CALLING_CLASS, CALLING_CLASS_PATH, CALLING_MODULE].include? key
        true
      else
        @real.exist?(key)
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
