require 'puppet/network/authstore'
require 'puppet/error'

module Puppet::Network

# this exception is thrown when a request is not authenticated
class AuthorizationError < Puppet::Error; end

# Rights class manages a list of ACLs for paths.
class Rights
  # Check that name is allowed or not
  def allowed?(name, *args)
    !is_forbidden_and_why?(name, :node => args[0], :ip => args[1])
  end

  def is_request_forbidden_and_why?(method, path, params)
    methods_to_check = if method == :head
                         # :head is ok if either :find or :save is ok.
                         [:find, :save]
                       else
                         [method]
                       end
    authorization_failure_exceptions = methods_to_check.map do |m|
      is_forbidden_and_why?(path, params.merge({:method => m}))
    end
    if authorization_failure_exceptions.include? nil
      # One of the methods we checked is ok, therefore this request is ok.
      nil
    else
      # Just need to return any of the failure exceptions.
      authorization_failure_exceptions.first
    end
  end

  def is_forbidden_and_why?(name, args = {})
    res = :nomatch
    right = @rights.find do |acl|
      found = false
      # an acl can return :dunno, which means "I'm not qualified to answer your question,
      # please ask someone else". This is used when for instance an acl matches, but not for the
      # current rest method, where we might think some other acl might be more specific.
      if match = acl.match?(name)
        args[:match] = match
        if (res = acl.allowed?(args[:node], args[:ip], args)) != :dunno
          # return early if we're allowed
          return nil if res
          # we matched, select this acl
          found = true
        end
      end
      found
    end

    # if we end up here, then that means we either didn't match or failed, in any
    # case will return an error to the outside world
    host_description = args[:node] ? "#{args[:node]}(#{args[:ip]})" : args[:ip]

    msg = "#{host_description} access to #{name} [#{args[:method]}]"

    if args[:authenticated]
      msg += " authenticated "
    end

    if right
      msg += " at #{right.file}:#{right.line}"
    end

    AuthorizationError.new("Forbidden request: #{msg}")
  end

  def initialize
    @rights = []
  end

  def [](name)
    @rights.find { |acl| acl == name }
  end

  def empty?
    @rights.empty?
  end

  def include?(name)
    @rights.include?(name)
  end

  def each
    @rights.each { |r| yield r.name,r }
  end

  # Define a new right to which access can be provided.
  def newright(name, line=nil, file=nil)
    add_right( Right.new(name, line, file) )
  end

  private

  def add_right(right)
    @rights << right
    right
  end

  # Retrieve a right by name.
  def right(name)
    self[name]
  end

  # A right.
  class Right < Puppet::Network::AuthStore
    attr_accessor :name, :key
    # Overriding Object#methods sucks for debugging. If we're in here in the
    # future, it would be nice to rename Right#methods
    attr_accessor :methods, :environment, :authentication
    attr_accessor :line, :file

    ALL = [:save, :destroy, :find, :search]

    Puppet::Util.logmethods(self, true)

    def initialize(name, line, file)
      @methods = []
      @environment = []
      @authentication = true # defaults to authenticated
      @name = name
      @line = line || 0
      @file = file
      @methods = ALL

      case name
      when /^\//
        @key = Regexp.new("^" + Regexp.escape(name))
      when /^~/ # this is a regex
        @name = name.gsub(/^~\s+/,'')
        @key = Regexp.new(@name)
      else
        raise ArgumentError, "Unknown right type '#{name}'"
      end

      super()
    end

    def to_s
      "access[#{@name}]"
    end

    # There's no real check to do at this point
    def valid?
      true
    end

    # does this right is allowed for this triplet?
    # if this right is too restrictive (ie we don't match this access method)
    # then return :dunno so that upper layers have a chance to try another right
    # tailored to the given method
    def allowed?(name, ip, args = {})
      if not @methods.include?(args[:method])
        return :dunno
      elsif @environment.size > 0 and not @environment.include?(args[:environment])
        return :dunno
      elsif (@authentication and not args[:authenticated])
        return :dunno
      end

      begin
        # make sure any capture are replaced if needed
        interpolate(args[:match]) if args[:match]
        res = super(name,ip)
      ensure
        reset_interpolation
      end
      res
    end

    # restrict this right to some method only
    def restrict_method(m)
      m = m.intern if m.is_a?(String)

      raise ArgumentError, "'#{m}' is not an allowed value for method directive" unless ALL.include?(m)

      # if we were allowing all methods, then starts from scratch
      if @methods === ALL
        @methods = []
      end

      raise ArgumentError, "'#{m}' is already in the '#{name}' ACL" if @methods.include?(m)

      @methods << m
    end

    def restrict_environment(environment)
      env = Puppet.lookup(:environments).get(environment)
      raise ArgumentError, "'#{env}' is already in the '#{name}' ACL" if @environment.include?(env)

      @environment << env
    end

    def restrict_authenticated(authentication)
      case authentication
      when "yes", "on", "true", true
        authentication = true
      when "no", "off", "false", false, "all" ,"any", :all, :any
        authentication = false
      else
        raise ArgumentError, "'#{name}' incorrect authenticated value: #{authentication}"
      end
      @authentication = authentication
    end

    def match?(key)
      # otherwise match with the regex
      self.key.match(key)
    end

    def ==(name)
      self.name == name.gsub(/^~\s+/,'')
    end
  end
end
end
