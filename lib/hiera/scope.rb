class Hiera
  class Scope
    CALLING_CLASS = 'calling_class'.freeze
    CALLING_CLASS_PATH = 'calling_class_path'.freeze
    CALLING_MODULE = 'calling_module'.freeze
    MODULE_NAME = 'module_name'.freeze

    CALLING_KEYS = [CALLING_CLASS, CALLING_CLASS_PATH, CALLING_MODULE].freeze
    EMPTY_STRING = ''.freeze

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
        ans = safe_lookupvar(MODULE_NAME)
      else
        ans = safe_lookupvar(key)
      end
      ans == EMPTY_STRING ? nil : ans
    end

    # This method is used to handle the throw of :undefined_variable since when
    # strict variables is not in effect, missing handling of the throw leads to
    # a more expensive code path.
    #
    def safe_lookupvar(key)
      reason = catch :undefined_variable do
        return @real.lookupvar(key)
      end

      case Puppet[:strict]
      when :off
        # do nothing
      when :warning
        Puppet.warn_once(Puppet::Parser::Scope::UNDEFINED_VARIABLES_KIND, _("Variable: %{name}") % { name: key },
        _("Undefined variable '%{name}'; %{reason}") % { name: key, reason: reason } )
      when :error
        raise ArgumentError, _("Undefined variable '%{name}'; %{reason}") % { name: key, reason: reason }
      end
      nil
    end
    private :safe_lookupvar

    def exist?(key)
      CALLING_KEYS.include?(key) || @real.exist?(key)
    end

    def include?(key)
      CALLING_KEYS.include?(key) || @real.include?(key)
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
