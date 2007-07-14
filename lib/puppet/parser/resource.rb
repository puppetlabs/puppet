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

    attr_accessor :source, :line, :file, :scope, :rails_id
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

    # Add any metaparams defined in our scope. This actually adds any metaparams
    # from any parent scope, and there's currently no way to turn that off.
    def addmetaparams
        Puppet::Type.eachmetaparam do |name|
            next if self[name]
            if val = scope.lookupvar(name.to_s, false)
                unless val == :undefined
                    set Param.new(:name => name, :value => val, 
                                  :source => scope.source)
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
                                  :title => self.title,
                                  :arguments => self.to_hash,
                                  :scope => self.scope,
                                  :virtual => self.virtual,
                                  :exported => self.exported
            )
        elsif builtin?
            devfail "Cannot evaluate a builtin type"
        else
            self.fail "Cannot find definition %s" % self.type
        end
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

    def modify_rails(db_resource)
        args = rails_args
        args.each do |param, value|
            db_resource[param] = value unless db_resource[param] == value
        end

        # Handle file specially
        if (self.file and  
            (!db_resource.file or db_resource.file != self.file))
            db_resource.file = self.file
        end
        
        updated_params = @params.inject({}) do |hash, ary|
            hash[ary[0].to_s] = ary[1]
            hash
        end
        
        db_resource.ar_hash_merge(db_resource.get_params_hash(db_resource.param_values), updated_params,
                                  :create => Proc.new { |name, parameter|
                                      parameter.to_rails(db_resource)
                                  }, :delete => Proc.new { |values|
                                      values.each { |value| db_resource.param_values.delete(value) }
                                  }, :modify => Proc.new { |db, mem|
                                      mem.modify_rails_values(db)
                                  })
        
        updated_tags = tags.inject({}) { |hash, tag| 
            hash[tag] = tag
            hash
        }
            
        db_resource.ar_hash_merge(db_resource.get_tag_hash(), 
                                  updated_tags,
                                  :create => Proc.new { |name, tag|
                                      db_resource.add_resource_tag(name)
                                  }, :delete => Proc.new { |tag|
                                      db_resource.resource_tags.delete(tag)
                                  }, :modify => Proc.new { |db, mem|
                                      # nothing here
                                  })
    end

    # This *significantly* reduces the number of calls to Puppet.[].
    def paramcheck?
        unless defined? @@paramcheck
            @@paramcheck = Puppet[:paramcheck]
        end
        @@paramcheck
    end

    # Verify that all passed parameters are valid.  This throws an error if
    #  there's a problem, so we don't have to worry about the return value.
    def paramcheck(param)
        param = param.to_s
        # Now make sure it's a valid argument to our class.  These checks
        # are organized in order of commonhood -- most types, it's a valid 
        # argument and paramcheck is enabled.
        if @ref.typeclass.validattr?(param)
            true
        elsif %w{name title}.include?(param) # always allow these
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
    def set(param, value = nil, source = nil)
        if value and source
            param = Puppet::Parser::Resource::Param.new(
                :name => param, :value => value, :source => source
            )
        elsif ! param.is_a?(Puppet::Parser::Resource::Param)
            raise ArgumentError, "Must pass a parameter or all necessary values"
        end
        # Because definitions are now parse-time, I can paramcheck immediately.
        paramcheck(param.name)

        if current = @params[param.name]
            # This is where we'd ignore any equivalent values if we wanted to,
            # but that would introduce a lot of really bad ordering issues.
            if param.source.child_of?(current.source)
                if param.add
                    # Merge with previous value.
                    param.value = [ current.value, param.value ].flatten
                end

                # Replace it, keeping all of its info.
                @params[param.name] = param
            else
                if Puppet[:trace]
                    puts caller
                end
                msg = "Parameter '%s' is already set on %s" % 
                    [param.name, self.to_s]
                if current.source.to_s != ""
                    msg += " by %s" % current.source
                end
                if current.file or current.line
                    fields = []
                    fields << current.file if current.file
                    fields << current.line.to_s if current.line
                    msg += " at %s" % fields.join(":")
                end
                msg += "; cannot redefine"
                error = Puppet::ParseError.new(msg)
                error.file = param.file if param.file
                error.line = param.line if param.line
                raise error
            end
        else
            if self.source == param.source or param.source.child_of?(self.source)
                @params[param.name] = param
            else
                fail Puppet::ParseError, "Only subclasses can set parameters"
            end
        end
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
            # Skip "undef" values.
            if param.value != :undef
                hash[param.name] = param.value
            end
            hash
        end
    end

    # Turn our parser resource into a Rails resource.  
    def to_rails(host)
        args = rails_args

        db_resource = host.resources.build(args)

        # Handle file specially
        db_resource.file = self.file

        @params.each { |name, param|
            param.to_rails(db_resource)
        }
        
        tags.each { |tag| db_resource.add_resource_tag(tag) }

        return db_resource
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

            # If the value is an array with only one value, then
            # convert it to a single value.  This is largely so that
            # the database interaction doesn't have to worry about
            # whether it returns an array or a string.
            obj[p.to_s] = if v.is_a?(Array) and v.length == 1
                              v[0]
                          else
                              v
                          end
        end

        obj.file = self.file
        obj.line = self.line

        obj.tags = self.tags

        return obj
    end

    def virtual?
        self.virtual
    end
    
    private
    def rails_args
        return [:type, :title, :line, :exported].inject({}) do |hash, param|
            # 'type' isn't a valid column name, so we have to use another name.
            to = (param == :type) ? :restype : param
            if value = self.send(param)
                hash[to] = value 
            end
            hash
        end
    end
end

# $Id$
