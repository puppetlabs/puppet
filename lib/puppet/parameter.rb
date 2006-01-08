module Puppet
    class Parameter < Puppet::Element
        class << self
            attr_reader :validater, :munger, :name, :default
            attr_accessor :ismetaparameter, :element

            # This means that 'nil' is an invalid default value.
            def defaultto(value = nil, &block)
                if block
                    @default = block
                else
                    @default = value
                end
            end

            # Store documentation for this parameter.
            def desc(str)
                @doc = str
            end

            # This is how we munge the value.  Basically, this is our
            # opportunity to convert the value from one form into another.
            def munge(&block)
                # I need to wrap the unsafe version in begin/rescue statements,
                # but if I directly call the block then it gets bound to the
                # class's context, not the instance's, thus the two methods,
                # instead of just one.
                define_method(:unsafe_munge, &block)

                define_method(:munge) do |*args|
                    begin
                        unsafe_munge(*args)
                    rescue Puppet::Error => detail
                        Puppet.debug "Reraising %s" % detail
                        raise
                    rescue => detail
                        raise Puppet::DevError, "Munging failed for class %s: %s" %
                            [self.name, detail]
                    end
                end
                #@munger = block
            end

            def inspect
                "Parameter(#{self.name})"
            end

            # Mark whether we're the namevar.
            def isnamevar
                @isnamevar = true
                @required = true
            end

            # Is this parameter the namevar?  Defaults to false.
            def isnamevar?
                if defined? @isnamevar
                    return @isnamevar
                else
                    return false
                end
            end

            # This parameter is required.
            def isrequired
                @required = true
            end

            # Is this parameter required?  Defaults to false.
            def required?
                if defined? @required
                    return @required
                else
                    return false
                end
            end

            def to_s
                if self.ismetaparameter
                    "Puppet::Type::" + @name.to_s.capitalize
                else
                    self.element.to_s + @name.to_s.capitalize
                end
            end

            # Verify that we got a good value
            def validate(&block)
                #@validater = block
                define_method(:unsafe_validate, &block)

                define_method(:validate) do |*args|
                    begin
                        unsafe_validate(*args)
                    rescue ArgumentError, Puppet::Error, TypeError
                        raise
                    rescue => detail
                        raise Puppet::DevError,
                            "Validate method failed for class %s: %s" %
                            [self.name, detail]
                    end
                end
            end
        end

        # Just a simple method to proxy instance methods to class methods
        def self.proxymethods(*values)
            values.each { |val|
                eval "def #{val}; self.class.#{val}; end"
            }
        end

        # And then define one of these proxies for each method in our
        # ParamHandler class.
        proxymethods("required?", "default", "isnamevar?")

        attr_accessor :parent

        # This doesn't work, because the instance_eval doesn't bind the inner block
        # only the outer one.
#        def munge(value)
#            if munger = self.class.munger
#                return @parent.instance_eval {
#                    munger.call(value)
#                }
#            else
#                return value
#            end
#        end
#
#        def validate(value)
#            if validater = self.class.validater
#                return @parent.instance_eval {
#                    validater.call(value)
#                }
#            end
#        end

        def default
            default = self.class.default
            if default.is_a?(Proc)
                val = self.instance_eval(&default)
                return val
            else
                return default
            end
        end

        # This should only be called for parameters, but go ahead and make
        # it possible to call for states, too.
        def value
            if self.is_a?(Puppet::State)
                return self.should
            else
                return @value
            end
        end

        # Store the value provided.  All of the checking should possibly be
        # late-binding (e.g., users might not exist when the value is assigned
        # but might when it is asked for).
        def value=(value)
            # If we're a state, just hand the processing off to the should method.
            if self.is_a?(Puppet::State)
                return self.should = value
            end
            if respond_to?(:validate)
                validate(value)
            end

            if respond_to?(:munge)
                value = munge(value)
            end
            @value = value
        end

        def to_s
            "%s => %s" % [self.class.name, self.value]
        end

        def inspect
            s = "Parameter(%s = %s" % [self.name, self.value || "nil"]
            if defined? @parent
                s += ", @parent = %s)" % @parent
            else
                s += ")"
            end
        end

        def name
            self.class.name
        end

        def to_s
            s = "Parameter(%s)" % self.name
        end
    end
end
