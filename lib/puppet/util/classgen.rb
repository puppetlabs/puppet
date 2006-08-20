module Puppet
    class ConstantAlreadyDefined < Error; end
    class SubclassAlreadyDefined < Error; end
end

module Puppet::Util::ClassGen
    include Puppet::Util::MetaID
    include Puppet::Util::MethodHelper
    include Puppet::Util

    # Create a new subclass.  Valid options are:
    # * <tt>:array</tt>: An array of existing classes.  If specified, the new
    #   class is added to this array.
    # * <tt>:attributes</tt>: A hash of attributes to set before the block is
    #   evaluated.
    # * <tt>:block</tt>: The block to evaluate in the context of the class.
    #   You can also just pass the block normally, but it will still be evaluated
    #   with <tt>class_eval</tt>.
    # * <tt>:constant</tt>: What to set the constant as.  Defaults to the
    #   capitalized name.
    # * <tt>:hash</tt>: A hash of existing classes.  If specified, the new
    #   class is added to this hash, and it is also used for overwrite tests.
    # * <tt>:overwrite</tt>: Whether to overwrite an existing class.
    # * <tt>:parent</tt>: The parent class for the generated class.  Defaults to
    #   self.
    # * <tt>:prefix</tt>: The constant prefix.  Default to nothing; if specified,
    #   the capitalized name is appended and the result is set as the constant.
    def genclass(name, options = {}, &block)
        options = symbolize_options(options)
        parent = options[:parent] || self

        name = symbolize(name.to_s.downcase)

        # Create the class, with the correct name.
        klass = Class.new(parent) do
            @name = name
        end

        unless const = options[:constant]
            prefix = options[:prefix] || ""
            const = prefix + name2const(name)
        end

        if const_defined? const
            if options[:overwrite]
                Puppet.info "Redefining %s subclass %s" % [parent, name]
                remove_const(const)
            else
                raise Puppet::ConstantAlreadyDefined,
                    "Class %s is already defined in %s" % [const, parent]
            end
        end
        const_set(const, klass)

        # Initialize any necessary variables.
        if klass.respond_to? :initvars
            klass.initvars
        end

        if attrs = options[:attributes]
            attrs.each do |param, value|
                method = param.to_s + "="
                if klass.respond_to? method
                    klass.send(method, value)
                end
            end
        end

        block ||= options[:block]

        # Evaluate the passed block if there is one.  This should usually
        # define all of the work.
        if block
            klass.class_eval(&block)
        end

        # If we were told to stick it in a hash, then do so
        if hash = options[:hash]
            if hash.include? name and ! options[:overwrite]
                raise SubclassAlreadyDefined,
                    "Already a generated class named %s" % name
            end

            hash[name] = klass
        end

        # If we were told to stick it in a hash, then do so
        if array = options[:array]
            if (klass.respond_to? :name and
                            array.find { |c| c.name == name } and
                            ! options[:overwrite])
                raise SubclassAlreadyDefined,
                    "Already a generated class named %s" % name
            end

            array << klass
        end

        return klass
    end

    # Remove an existing class
    def rmclass(name, options)
        options = symbolize_options(options)
        const = name2const(name)
        retval = false
        if const_defined? const
            remove_const(const)
            retval = true
        end

        if hash = options[:hash] and hash.include? name
            hash.delete(name)
            retval = true
        end

        # Let them know whether we did actually delete a subclass.
        return retval
    end

    private

    def name2const(name)
        name.to_s.capitalize
    end
end

# $Id$
