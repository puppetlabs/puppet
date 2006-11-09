# A resource that we're managing.  This handles making sure that only subclasses
# can set parameters.
class Puppet::Parser::Resource
    require 'puppet/parser/resource/param'
    require 'puppet/parser/resource/reference'
    ResParam = Struct.new :name, :value, :source, :line, :file
    include Puppet::Util
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors
    include Puppet::Util::Logging

    attr_accessor :source, :line, :file, :scope
    attr_accessor :virtual, :override, :params, :translated

    attr_reader :exported

    attr_writer :tags

    # Proxy a few methods to our @ref object.
    [:builtin?, :type, :title].each do |method|
        define_method(method) do
            @ref.send(method)
        end
    end

    # Set up some boolean test methods
    [:exported, :translated, :override].each do |method|
        newmeth = (method.to_s + "?").intern
        define_method(newmeth) do
            self.send(method)
        end
    end

    def [](param)
        param = symbolize(param)
        if param == :title
            return self.title
        end
        if @params.has_key?(param)
            @params[param].value
        else
            nil
        end
    end

    # Add default values from our definition.
    def adddefaults
        defaults = scope.lookupdefaults(self.type)

        defaults.each do |name, param|
            unless @params.include?(param.name)
                self.debug "Adding default for %s" % param.name

                @params[param.name] = param
            end
        end
    end

    # Add any metaparams defined in our scope.  This actually adds any metaparams
    # from any parent scope, and there's currently no way to turn that off.
    def addmetaparams
        Puppet::Type.eachmetaparam do |name|
            if val = scope.lookupvar(name.to_s, false)
                unless val == :undefined
                    set Param.new(:name => name, :value => val, :source => scope.source)
                end
            end
        end
    end

    # Add any overrides for this object.
    def addoverrides
        overrides = scope.lookupoverrides(self)

        overrides.each do |over|
            self.merge(over)
        end

        overrides.clear
    end

    def builtin=(bool)
        @ref.builtin = bool
    end

    # Retrieve the associated definition and evaluate it.
    def evaluate
        if klass = @ref.definedtype
            finish()
            scope.deleteresource(self)
            return klass.evaluate(:scope => scope,
                                  :type => self.type,
                                  :name => self.title,
                                  :arguments => self.to_hash,
                                  :scope => self.scope,
                                  :exported => self.exported
            )
        elsif builtin?
            devfail "Cannot evaluate a builtin type"
        else
            self.fail "Cannot find definition %s" % self.type
        end


#        if builtin?
#            devfail "Cannot evaluate a builtin type"
#        end
#
#        unless klass = scope.finddefine(self.type)
#            self.fail "Cannot find definition %s" % self.type
#        end
#
#        finish()
#
#        scope.deleteresource(self)
#
#        return klass.evaluate(:scope => scope,
#                              :type => self.type,
#                              :name => self.title,
#                              :arguments => self.to_hash,
#                              :scope => self.scope,
#                              :exported => self.exported
#        )
    ensure
        @evaluated = true
    end

    def exported=(value)
        if value
            @virtual = true
            @exported = value
        else
            @exported = value
        end
    end

    def evaluated?
        if defined? @evaluated and @evaluated
            true
        else
            false
        end
    end

    # Do any finishing work on this object, called before evaluation or
    # before storage/translation.
    def finish
        addoverrides()
        adddefaults()
        addmetaparams()
    end

    def initialize(options)
        options = symbolize_options(options)

        # Collect the options necessary to make the reference.
        refopts = [:type, :title].inject({}) do |hash, param|
            hash[param] = options[param]
            options.delete(param)
            hash
        end

        @params = {}
        tmpparams = nil
        if tmpparams = options[:params]
            options.delete(:params)
        end

        # Now set the rest of the options.
        set_options(options)

        @ref = Reference.new(refopts)

        requiredopts(:scope, :source)

        @ref.scope = self.scope

        if tmpparams
            tmpparams.each do |param|
                # We use the method here, because it does type-checking.
                set(param)
            end
        end
    end

    # Merge an override resource in.
    def merge(resource)
        # Some of these might fail, but they'll fail in the way we want.
        resource.params.each do |name, param|
            set(param)
        end
    end

    # This *significantly* reduces the number of calls to Puppet.[].
    def paramcheck?
        unless defined? @@paramcheck
            @@paramcheck = Puppet[:paramcheck]
        end
        @@paramcheck
    end

    # Verify that all passed parameters are valid.  This throws an error if there's
    # a problem, so we don't have to worry about the return value.
    def paramcheck(param)
        # Now make sure it's a valid argument to our class.  These checks
        # are organized in order of commonhood -- most types, it's a valid argument
        # and paramcheck is enabled.
        if @ref.typeclass.validattr?(param)
            true
        elsif (param == "name" or param == "title") # always allow these
            true
        elsif paramcheck?
            self.fail Puppet::ParseError, "Invalid parameter '%s' for type '%s'" %
                    [param.inspect, @ref.type]
        end
    end

    # A temporary occasion, until I get paths in the scopes figured out.
    def path
        to_s
    end

    # Return the short version of our name.
    def ref
        @ref.to_s
    end

    # You have to pass a Resource::Param to this.
    def set(param)
        # Because definitions are now parse-time, I can paramcheck immediately.
        paramcheck(param.name)

        if current = @params[param.name]
            # XXX Should we ignore any settings that have the same values?
            if param.source.child_of?(current.source)
                # Replace it, keeping all of its info.
                @params[param.name] = param
            else
                fail Puppet::ParseError, "Parameter %s is already set on %s by %s" %
                    [param.name, self.to_s, param.source]
            end
        else
            if self.source == param.source or param.source.child_of?(self.source)
                @params[param.name] = param
            else
                fail Puppet::ParseError, "Only subclasses can set parameters"
            end
        end
    end

    # Store our object as a Rails object.  We need the host object we're storing it
    # with.
    def store(host)
        args = {}
        #FIXME: support files/lines, etc.
        #%w{type title tags file line exported}.each do |param|
        %w{type title tags exported}.each do |param|
            if value = self.send(param)
                args[param] = value
            end
        end

        args = symbolize_options(args)

        # Let's see if the object exists
        if obj = host.resources.find_by_type_and_title(self.type, self.title)
            # We exist
            args.each do |param, value|
                obj[param] = value
            end
        else
            # Else create it anew
            obj = host.resources.build(args)
        end

        # Either way, now add our parameters
        @params.each do |name, param|
            param.store(obj)
        end

        return obj
    end

    def tags
        unless defined? @tags
            @tags = scope.tags
            @tags << self.type
        end
        @tags
    end

    def to_hash
        @params.inject({}) do |hash, ary|
            param = ary[1]
            hash[param.name] = param.value
            hash
        end
    end

    def to_s
        self.ref
    end

    # Translate our object to a transportable object.
    def to_trans
        unless builtin?
            devfail "Tried to translate a non-builtin resource"
        end

        return nil if virtual?

        # Now convert to a transobject
        obj = Puppet::TransObject.new(@ref.title, @ref.type)
        to_hash.each do |p, v|
            if v.is_a?(Reference)
                v = v.to_ref
            elsif v.is_a?(Array)
                v = v.collect { |av|
                    if av.is_a?(Reference)
                        av = av.to_ref
                    end
                    av
                }
            end
            obj[p.to_s] = v
        end

        obj.file = self.file
        obj.line = self.line

        obj.tags = self.tags

        return obj
    end

    def virtual?
        self.virtual
    end
end

# $Id$
