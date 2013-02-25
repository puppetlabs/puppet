class Hiera
  class Scope
    attr_reader :real

    def initialize(real)
      @real = real
    end


    def [](key)
      if key == "calling_class"
        ans = find_hostclass(@real)
      elsif key == "calling_module"
        ans = @real.source.module_name.downcase
      else
        ans = @real.lookupvar(key)
      end

      # damn you puppet visual basic style variables.
      return nil if ans.nil? or ans == ""
      return ans
    end

    def include?(key)
      return true if ["calling_class", "calling_module"].include?(key)

      return @real.lookupvar(key) != ""
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

