require 'puppet/network/authstore'

# Define a set of rights and who has access to them.
# There are two types of rights:
#  * named rights (ie a common string)
#  * path based rights (which are matched on a longest prefix basis)
class Puppet::Network::Rights

    # We basically just proxy directly to our rights.  Each Right stores
    # its own auth abilities.
    [:allow, :deny, :restrict_method, :restrict_environment].each do |method|
        define_method(method) do |name, *args|
            if obj = self[name]
                obj.send(method, *args)
            else
                raise ArgumentError, "Unknown right '%s'" % name
            end
        end
    end

    def allowed?(name, *args)
        res = :nomatch
        right = @rights.find do |acl|
            # an acl can return :dunno, which means "I'm not qualified to answer your question, 
            # please ask someone else". This is used when for instance an acl matches, but not for the
            # current rest method, where we might think some other acl might be more specific.
            if match = acl.match?(name)
                args << match
                if (res = acl.allowed?(*args)) != :dunno
                    return res
                end
            end
            false
        end

        # if allowed or denied, tell it to the world
        return res unless res == :nomatch

        # there were no rights allowing/denying name
        # if name is not a path, let's throw
        raise ArgumentError, "Unknown namespace right '%s'" % name unless name =~ /^\//

        # but if this was a path, we implement a deny all policy by default
        # on unknown rights.
        return false
    end

    def initialize()
        @rights = []
    end

    def [](name)
        @rights.find { |acl| acl == name }
    end

    def include?(name)
        @rights.include?(name)
    end

    def each
        @rights.each { |r| yield r.name,r }
    end

    # Define a new right to which access can be provided.
    def newright(name, line=nil)
        add_right( Right.new(name, line) )
    end

    private

    def add_right(right)
        if right.acl_type == :name and include?(right.key)
            raise ArgumentError, "Right '%s' already exists"
        end
        @rights << right
        sort_rights
        right
    end

    def sort_rights
        @rights.sort!
    end

    # Retrieve a right by name.
    def right(name)
        self[name]
    end

    # A right.
    class Right < Puppet::Network::AuthStore
        attr_accessor :name, :key, :acl_type, :line
        attr_accessor :methods, :environment

        ALL = [:save, :destroy, :find, :search]

        Puppet::Util.logmethods(self, true)

        def initialize(name, line)
            @methods = []
            @environment = []
            @name = name
            @line = line || 0

            case name
            when Symbol
                @acl_type = :name
                @key = name
            when /^\[(.+)\]$/
                @acl_type = :name
                @key = $1.intern if name.is_a?(String)
            when /^\//
                @acl_type = :regex
                @key = Regexp.new("^" + Regexp.escape(name))
                @methods = ALL
            when /^~/ # this is a regex
                @acl_type = :regex
                @name = name.gsub(/^~\s+/,'')
                @key = Regexp.new(@name)
                @methods = ALL
            else
                raise ArgumentError, "Unknown right type '%s'" % name
            end
            super()
        end

        def to_s
            "access[%s]" % @name
        end

        # There's no real check to do at this point
        def valid?
            true
        end

        def regex?
            acl_type == :regex
        end

        # does this right is allowed for this triplet?
        # if this right is too restrictive (ie we don't match this access method)
        # then return :dunno so that upper layers have a chance to try another right
        # tailored to the given method
        def allowed?(name, ip, method = nil, environment = nil, match = nil)
            return :dunno if acl_type == :regex and not @methods.include?(method)
            return :dunno if acl_type == :regex and @environment.size > 0 and not @environment.include?(environment)

            if acl_type == :regex and match # make sure any capture are replaced
                interpolate(match)
            end

            res = super(name,ip)

            if acl_type == :regex
                reset_interpolation
            end
            res
        end

        # restrict this right to some method only
        def restrict_method(m)
            m = m.intern if m.is_a?(String)

            unless ALL.include?(m)
                raise ArgumentError, "'%s' is not an allowed value for method directive" % m
            end

            # if we were allowing all methods, then starts from scratch
            if @methods === ALL
                @methods = []
            end

            if @methods.include?(m)
                raise ArgumentError, "'%s' is already in the '%s' ACL" % [m, name]
            end

            @methods << m
        end

        def restrict_environment(env)
            env = Puppet::Node::Environment.new(env)
            if @environment.include?(env)
                raise ArgumentError, "'%s' is already in the '%s' ACL" % [env, name]
            end

            @environment << env
        end

        def match?(key)
            # if we are a namespace compare directly
            return self.key == namespace_to_key(key) if acl_type == :name

            # otherwise match with the regex
            return self.key.match(key)
        end

        def namespace_to_key(key)
            key = key.intern if key.is_a?(String)
            key
        end

        # this is where all the magic happens.
        # we're sorting the rights array with this scheme:
        #  * namespace rights are all in front
        #  * regex path rights are then all queued in file order
        def <=>(rhs)
            # move namespace rights at front
            if self.acl_type != rhs.acl_type
                return self.acl_type == :name ? -1 : 1
            end

            # sort by creation order (ie first match appearing in the file will win)
            # that is don't sort, in which case the sort algorithm will order in the
            # natural array order (ie the creation order)
            return 0
        end

        def ==(name)
            return self.key == namespace_to_key(name) if acl_type == :name
            return self.name == name
        end

    end

end

