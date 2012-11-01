class Hiera
  class Scope
    attr_reader :real

    def initialize(real)
      @real = real
    end


    def [](key)
      if key == "calling_class"
        def recurse_for_hostclass(scope)
          if scope.source and scope.source.type == :hostclass
            return scope.source.name
          elsif scope.parent
            return recurse_for_hostclass(scope.parent)
          else
            return nil
          end
        end
        ans = recurse_for_hostclass(@real)
      elsif key == "calling_module"
        ans = @real.source.module_name
      else
        ans = @real.lookupvar(key)
      end

      # damn you puppet visual basic style variables.
      return nil if ans.nil? or ans == ""
      return ans.downcase
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
  end
end

