module Puppet::Util::Variables
    def inithooks
        @instance_init_hooks.dup
    end

    def initvars
        return unless defined? @class_init_hooks
        self.inithooks.each do |var, value|
            if value.is_a?(Class)
                instance_variable_set("@" + var.to_s, value.new)
            else
                instance_variable_set("@" + var.to_s, value)
            end
        end
    end

    def instancevar(hash)
        @instance_init_hooks ||= {}

        unless method_defined?(:initvars)
            define_method(:initvars) do
                self.class.inithooks.each do |var, value|
                    if value.is_a?(Class)
                        instance_variable_set("@" + var.to_s, value.new)
                    else
                        instance_variable_set("@" + var.to_s, value)
                    end
                end
            end
        end
        hash.each do |var, value|
            raise("Already initializing %s" % var) if @instance_init_hooks[var]

            @instance_init_hooks[var] = value
        end
    end
end

