require 'puppet/resource'

# The primary difference between this class and its
# parent is that this class has rules on who can set
# parameters
class Puppet::Parser::Resource < Puppet::Resource
    require 'puppet/parser/resource/param'
    require 'puppet/resource'
    require 'puppet/util/tagging'
    require 'puppet/file_collection/lookup'
    require 'puppet/parser/yaml_trimmer'
    require 'puppet/resource/type_collection_helper'

    include Puppet::FileCollection::Lookup
    include Puppet::Resource::TypeCollectionHelper

    include Puppet::Util
    include Puppet::Util::MethodHelper
    include Puppet::Util::Errors
    include Puppet::Util::Logging
    include Puppet::Util::Tagging
    include Puppet::Parser::YamlTrimmer

    attr_accessor :source, :scope, :rails_id
    attr_accessor :virtual, :override, :translated, :catalog

    attr_reader :exported, :evaluated, :parameters

    # Determine whether the provided parameter name is a relationship parameter.
    def self.relationship_parameter?(name)
        unless defined?(@relationship_names)
            @relationship_names = Puppet::Type.relationship_params.collect { |p| p.name }
        end
        @relationship_names.include?(name)
    end

    # Set up some boolean test methods
    [:translated, :override, :evaluated].each do |method|
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
        if @parameters.has_key?(param)
            @parameters[param].value
        else
            nil
        end
    end

    def []=(param, value)
        set_parameter(param, value)
    end

    def eachparam
        @parameters.each do |name, param|
            yield param
        end
    end

    def environment
        scope.environment
    end

    # Retrieve the associated definition and evaluate it.
    def evaluate
        if klass = resource_type and ! builtin_type?
            finish()
            return klass.evaluate_code(self)
        elsif builtin?
            devfail "Cannot evaluate a builtin type (#{type})"
        else
            self.fail "Cannot find definition #{type}"
        end
    ensure
        @evaluated = true
    end

    # Mark this resource as both exported and virtual,
    # or remove the exported mark.
    def exported=(value)
        if value
            @virtual = true
            @exported = value
        else
            @exported = value
        end
    end

    # Do any finishing work on this object, called before evaluation or
    # before storage/translation.
    def finish
        return if finished?
        @finished = true
        add_defaults()
        add_metaparams()
        validate()
    end

    # Has this resource already been finished?
    def finished?
        defined?(@finished) and @finished
    end

    def initialize(*args)
        super

        unless scope
            raise ArgumentError, "Resources require a scope"
        end
        @source ||= scope.source
    end

    # Is this resource modeling an isomorphic resource type?
    def isomorphic?
        if builtin_type?
            return resource_type.isomorphic?
        else
            return true
        end
    end

    # Merge an override resource in.  This will throw exceptions if
    # any overrides aren't allowed.
    def merge(resource)
        # Test the resource scope, to make sure the resource is even allowed
        # to override.
        unless self.source.object_id == resource.source.object_id || resource.source.child_of?(self.source)
            raise Puppet::ParseError.new("Only subclasses can override parameters", resource.line, resource.file)
        end
        # Some of these might fail, but they'll fail in the way we want.
        resource.parameters.each do |name, param|
            override_parameter(param)
        end
    end

    # Unless we're running >= 0.25, we're in compat mode.
    def metaparam_compatibility_mode?
        ! (catalog and version = catalog.client_version and version = version.split(".") and version[0] == "0" and version[1].to_i >= 25)
    end

    # Return the resource name, or the title if no name
    # was specified.
    def name
        unless defined? @name
            @name = self[:name] || self.title
        end
        @name
    end

    def namespaces
        scope.namespaces
    end

    # A temporary occasion, until I get paths in the scopes figured out.
    def path
        to_s
    end

    # Define a parameter in our resource.
    # if we ever receive a parameter named 'tag', set
    # the resource tags with its value.
    def set_parameter(param, value = nil)
        if ! value.nil?
            param = Puppet::Parser::Resource::Param.new(
                :name => param, :value => value, :source => self.source
            )
        elsif ! param.is_a?(Puppet::Parser::Resource::Param)
            raise ArgumentError, "Must pass a parameter or all necessary values"
        end

        tag(*param.value) if param.name == :tag

        # And store it in our parameter hash.
        @parameters[param.name] = param
    end

    def to_hash
        @parameters.inject({}) do |hash, ary|
            param = ary[1]
            # Skip "undef" values.
            if param.value != :undef
                hash[param.name] = param.value
            end
            hash
        end
    end


    # Create a Puppet::Resource instance from this parser resource.
    # We plan, at some point, on not needing to do this conversion, but
    # it's sufficient for now.
    def to_resource
        result = Puppet::Resource.new(type, title)

        to_hash.each do |p, v|
            if v.is_a?(Puppet::Resource)
                v = Puppet::Resource.new(v.type, v.title)
            elsif v.is_a?(Array)
                # flatten resource references arrays
                if v.flatten.find { |av| av.is_a?(Puppet::Resource) }
                    v = v.flatten
                end
                v = v.collect do |av|
                    if av.is_a?(Puppet::Resource)
                        av = Puppet::Resource.new(av.type, av.title)
                    end
                    av
                end
            end

            # If the value is an array with only one value, then
            # convert it to a single value.  This is largely so that
            # the database interaction doesn't have to worry about
            # whether it returns an array or a string.
            result[p] = if v.is_a?(Array) and v.length == 1
                              v[0]
                          else
                              v
                          end
        end

        result.file = self.file
        result.line = self.line
        result.exported = self.exported
        result.virtual = self.virtual
        result.tag(*self.tags)

        return result
    end

    # Translate our object to a transportable object.
    def to_trans
        return nil if virtual?

        return to_resource.to_trans
    end

    # Convert this resource to a RAL resource.  We hackishly go via the
    # transportable stuff.
    def to_ral
        to_resource.to_ral
    end

    private

    # Add default values from our definition.
    def add_defaults
        scope.lookupdefaults(self.type).each do |name, param|
            unless @parameters.include?(name)
                self.debug "Adding default for %s" % name

                @parameters[name] = param.dup
            end
        end
    end

    def add_backward_compatible_relationship_param(name)
        # Skip metaparams for which we get no value.
        return unless val = scope.lookupvar(name.to_s, false) and val != :undefined

        # The default case: just set the value
        set_parameter(name, val) and return unless @parameters[name]

        # For relationship params, though, join the values (a la #446).
        @parameters[name].value = [@parameters[name].value, val].flatten
    end

    # Add any metaparams defined in our scope. This actually adds any metaparams
    # from any parent scope, and there's currently no way to turn that off.
    def add_metaparams
        compat_mode = metaparam_compatibility_mode?

        Puppet::Type.eachmetaparam do |name|
            next unless self.class.relationship_parameter?(name)
            add_backward_compatible_relationship_param(name) if compat_mode
        end
    end

    # Accept a parameter from an override.
    def override_parameter(param)
        # This can happen if the override is defining a new parameter, rather
        # than replacing an existing one.
        (set_parameter(param) and return) unless current = @parameters[param.name]

        # The parameter is already set.  Fail if they're not allowed to override it.
        unless param.source.child_of?(current.source)
            puts caller if Puppet[:trace]
            msg = "Parameter '%s' is already set on %s" % [param.name, self.to_s]
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
            raise Puppet::ParseError.new(msg, param.line, param.file)
        end

        # If we've gotten this far, we're allowed to override.

        # Merge with previous value, if the parameter was generated with the +> 
        # syntax.  It's important that we use a copy of the new param instance 
        # here, not the old one, and not the original new one, so that the source 
        # is registered correctly for later overrides but the values aren't 
        # implcitly shared when multiple resources are overrriden at once (see
        # ticket #3556).
        if param.add
            param = param.dup 
            param.value = [current.value, param.value].flatten
        end

        set_parameter(param)
    end

    # Make sure the resource's parameters are all valid for the type.
    def validate
        @parameters.each do |name, param|
            validate_parameter(name)
        end
    rescue => detail
        fail Puppet::ParseError, detail.to_s
    end

    private

    def extract_parameters(params)
        params.each do |param|
            # Don't set the same parameter twice
            if @parameters[param.name]
                self.fail Puppet::ParseError, "Duplicate parameter '%s' for on %s" %
                    [param.name, self.to_s]
            end

            set_parameter(param)
        end
    end
end
