require 'puppet/util/ldap'
require 'puppet/util/ldap/connection'
require 'puppet/util/ldap/generator'

# The configuration class for LDAP providers, plus
# connection handling for actually interacting with ldap.
class Puppet::Util::Ldap::Manager
  attr_reader :objectclasses, :puppet2ldap, :location, :rdn

  # A null-op that just returns the config.
  def and
    self
  end

  # Set the offset from the search base and return the config.
  def at(location)
    @location = location
    self
  end

  # The basic search base.
  def base
    [location, Puppet[:ldapbase]].join(",")
  end

  # Convert the name to a dn, then pass the args along to
  # our connection.
  def create(name, attributes)
    attributes = attributes.dup

    # Add the objectclasses
    attributes["objectClass"] = objectclasses.collect { |o| o.to_s }
    attributes["objectClass"] << "top" unless attributes["objectClass"].include?("top")

    attributes[rdn.to_s] = [name]

    # Generate any new values we might need.
    generate(attributes)

    # And create our resource.
    connect { |conn| conn.add dn(name), attributes }
  end

  # Open, yield, and close the connection.  Cannot be left
  # open, at this point.
  def connect
    #TRANSLATORS '#connect' is a method name and and should not be translated, 'block' refers to a Ruby code block
    raise ArgumentError, _("You must pass a block to #connect") unless block_given?

    unless @connection
      if Puppet[:ldaptls]
        ssl = :tls
      elsif Puppet[:ldapssl]
        ssl = true
      else
        ssl = false
      end
      options = {:ssl => ssl}
      if user = Puppet[:ldapuser] and user != ""
        options[:user] = user
      end
      if password = Puppet[:ldappassword] and password != ""
        options[:password] = password
      end
      @connection = Puppet::Util::Ldap::Connection.new(Puppet[:ldapserver], Puppet[:ldapport], options)
    end
    @connection.start
    begin
      yield @connection.connection
    ensure
      @connection.close
    end
    nil
  end

  # Convert the name to a dn, then pass the args along to
  # our connection.
  def delete(name)
    connect { |connection| connection.delete dn(name) }
  end

  # Calculate the dn for a given resource.
  def dn(name)
    ["#{rdn}=#{name}", base].join(",")
  end

  # Convert an ldap-style entry hash to a provider-style hash.
  def entry2provider(entry)
    #TRANSLATOR 'dn' refers to a 'distinguished name' in LDAP (Lightweight Directory Access Protocol) and they should not be translated
    raise ArgumentError, _("Could not get dn from ldap entry") unless entry["dn"]

    # DN is always a single-entry array.  Strip off the bits before the
    # first comma, then the bits after the remaining equal sign.  This is the
    # name.
    name = entry["dn"].dup.pop.split(",").shift.split("=").pop

    result = {:name => name}

    @ldap2puppet.each do |ldap, puppet|
      result[puppet] = entry[ldap.to_s] || :absent
    end

    result
  end

  # Create our normal search filter.
  def filter
    return(objectclasses.length == 1 ? "objectclass=#{objectclasses[0]}" : "(&(objectclass=" + objectclasses.join(")(objectclass=") + "))")
  end

  # Find the associated entry for a resource.  Returns a hash, minus
  # 'dn', or nil if the entry cannot be found.
  def find(name)
    connect do |conn|
      begin
        conn.search2(dn(name), 0, "objectclass=*") do |result|
          # Convert to puppet-appropriate attributes
          return entry2provider(result)
        end
      rescue
        return nil
      end
    end
  end

  # Declare a new attribute generator.
  def generates(parameter)
    @generators << Puppet::Util::Ldap::Generator.new(parameter)
    @generators[-1]
  end

  # Generate any extra values we need to make the ldap entry work.
  def generate(values)
    return unless @generators.length > 0

    @generators.each do |generator|
      # Don't override any values that might exist.
      next if values[generator.name]

      if generator.source
        unless value = values[generator.source]
          raise ArgumentError, _("%{source} must be defined to generate %{name}") %
              { source: generator.source, name: generator.name }
        end
        result = generator.generate(value)
      else
        result = generator.generate
      end

      result = [result] unless result.is_a?(Array)
      result = result.collect { |r| r.to_s }

      values[generator.name] = result
    end
  end

  def initialize
    @rdn = :cn
    @generators = []
  end

  # Specify what classes this provider models.
  def manages(*classes)
    @objectclasses = classes
    self
  end

  # Specify the attribute map.  Assumes the keys are the puppet
  # attributes, and the values are the ldap attributes, and creates a map
  # for each direction.
  def maps(attributes)
    # The map with the puppet attributes as the keys
    @puppet2ldap = attributes

    # and the ldap attributes as the keys.
    @ldap2puppet = attributes.inject({}) { |map, ary| map[ary[1]] = ary[0]; map }

    self
  end

  # Return the ldap name for a puppet attribute.
  def ldap_name(attribute)
    @puppet2ldap[attribute].to_s
  end

  # Convert the name to a dn, then pass the args along to
  # our connection.
  def modify(name, mods)
    connect { |connection| connection.modify dn(name), mods }
  end

  # Specify the rdn that we use to build up our dn.
  def named_by(attribute)
    @rdn = attribute
    self
  end

  # Return the puppet name for an ldap attribute.
  def puppet_name(attribute)
    @ldap2puppet[attribute]
  end

  # Search for all entries at our base.  A potentially expensive search.
  def search(sfilter = nil)
    sfilter ||= filter

    result = []
    connect do |conn|
      conn.search2(base, 1, sfilter) do |entry|
        result << entry2provider(entry)
      end
    end
    return(result.empty? ? nil : result)
  end

  # Update the ldap entry with the desired state.
  def update(name, is, should)
    if should[:ensure] == :absent
      Puppet.info _("Removing %{name} from ldap") % { name: dn(name) }
      delete(name)
      return
    end

    # We're creating a new entry
    if is.empty? or is[:ensure] == :absent
      Puppet.info _("Creating %{name} in ldap") % { name: dn(name) }
      # Remove any :absent params and :ensure, then convert the names to ldap names.
      attrs = ldap_convert(should)
      create(name, attrs)
      return
    end

    # We're modifying an existing entry.  Yuck.

    mods = []
    # For each attribute we're deleting that is present, create a
    # modify instance for deletion.
    [is.keys, should.keys].flatten.uniq.each do |property|
      # They're equal, so do nothing.
      next if is[property] == should[property]

      attributes = ldap_convert(should)

      prop_name = ldap_name(property).to_s

      # We're creating it.
      if is[property] == :absent or is[property].nil?
        mods << LDAP::Mod.new(LDAP::LDAP_MOD_ADD, prop_name, attributes[prop_name])
        next
      end

      # We're deleting it
      if should[property] == :absent or should[property].nil?
        mods << LDAP::Mod.new(LDAP::LDAP_MOD_DELETE, prop_name, [])
        next
      end

      # We're replacing an existing value
      mods << LDAP::Mod.new(LDAP::LDAP_MOD_REPLACE, prop_name, attributes[prop_name])
    end

    modify(name, mods)
  end

  # Is this a complete ldap configuration?
  def valid?
    location and objectclasses and ! objectclasses.empty? and puppet2ldap
  end

  private

  # Convert a hash of attributes to ldap-like forms.  This mostly means
  # getting rid of :ensure and making sure everything's an array of strings.
  def ldap_convert(attributes)
    attributes.reject { |param, value| value == :absent or param == :ensure }.inject({}) do |result, ary|
      value = (ary[1].is_a?(Array) ? ary[1] : [ary[1]]).collect { |v| v.to_s }
      result[ldap_name(ary[0])] = value
      result
    end
  end
end
