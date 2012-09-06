class Hiera
  class Scope
    attr_reader :real

    def initialize(real)
      @real = real
    end

    def [](key)
      if key == "calling_class"
        ans = @real.resource.name.to_s.downcase
      elsif key == "calling_module"
        ans = @real.resource.name.to_s.downcase.split("::").first
      else
        ans = @real.lookupvar(key)
      end

      # damn you puppet visual basic style variables.
      return nil if ans == ""
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
  end
end

