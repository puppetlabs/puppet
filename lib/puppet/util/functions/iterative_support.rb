module Puppet::Util::Functions
  module IterativeSupport
    def asserted_serving_size(pblock, name_of_first)
      size = pblock.parameter_count
      if size == 0
        raise ArgumentError, "#{self.class.name}(): block must define at least one parameter; value. Block has 0."
      end
      if size > 2
        raise ArgumentError, "#{self.class.name}(): block must define at most two parameters; #{name_of_first}, value. Block has #{size}; "+
        pblock.parameter_names.join(', ')
      end
      if pblock.last_captures_rest?
        # it has one or two parameters, and the last captures the rest - deliver args as if it accepts 2
        size = 2
      end
      size
    end

    def asserted_enumerable(obj)
      unless enum = Puppet::Pops::Types::Enumeration.enumerator(obj)
        raise ArgumentError, ("#{self.class.name}(): wrong argument type (#{obj.class}; must be something enumerable.")
      end
      enum
    end

  end
end