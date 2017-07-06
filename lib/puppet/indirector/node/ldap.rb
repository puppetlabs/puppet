require 'puppet/node'
require 'puppet/indirector/ldap'

class Puppet::Node::Ldap < Puppet::Indirector::Ldap
  desc "Search in LDAP for node configuration information.  See
  the [LDAP Nodes](https://docs.puppetlabs.com/guides/ldap_nodes.html) page for more information.  This will first
  search for whatever the certificate name is, then (if that name
  contains a `.`) for the short name, then `default`."

  # The attributes that Puppet class information is stored in.
  def class_attributes
    Puppet[:ldapclassattrs].split(/\s*,\s*/)
  end

  # Separate this out so it's relatively atomic.  It's tempting to call
  # process instead of name2hash() here, but it ends up being
  # difficult to test because all exceptions get caught by ldapsearch.
  # LAK:NOTE Unfortunately, the ldap support is too stupid to throw anything
  # but LDAP::ResultError, even on bad connections, so we are rough-handed
  # with our error handling.
  def name2hash(name)
    info = nil
    ldapsearch(search_filter(name)) { |entry| info = entry2hash(entry) }
    info
  end

  # Look for our node in ldap.
  def find(request)
    names = [request.key]
    names << request.key.sub(/\..+/, '') if request.key.include?(".") # we assume it's an fqdn
    names << "default"

    node = nil
    names.each do |name|
      next unless info = name2hash(name)

      merge_parent(info) if info[:parent]
      info[:environment] ||= request.environment
      node = info2node(request.key, info)
      break
    end

    node
  end

  # Find more than one node.  LAK:NOTE This is a bit of a clumsy API, because the 'search'
  # method currently *requires* a key.  It seems appropriate in some cases but not others,
  # and I don't really know how to get rid of it as a requirement but allow it when desired.
  def search(request)
    if classes = request.options[:class]
      classes = [classes] unless classes.is_a?(Array)
      filter = "(&(objectclass=puppetClient)(puppetclass=" + classes.join(")(puppetclass=") + "))"
    else
      filter = "(objectclass=puppetClient)"
    end

    infos = []
    ldapsearch(filter) { |entry| infos << entry2hash(entry, request.options[:fqdn]) }

    return infos.collect do |info|
      merge_parent(info) if info[:parent]
      info[:environment] ||= request.environment
      info2node(info[:name], info)
    end
  end

  # The parent attribute, if we have one.
  def parent_attribute
    if pattr = Puppet[:ldapparentattr] and ! pattr.empty?
      pattr
    else
      nil
    end
  end

  # The attributes that Puppet will stack as array over the full
  # hierarchy.
  def stacked_attributes
    Puppet[:ldapstackedattrs].split(/\s*,\s*/)
  end

  # Convert the found entry into a simple hash.
  def entry2hash(entry, fqdn = false)
    result = {}

    cn  = entry.dn[     /cn\s*=\s*([^,\s]+)/i,1]
    dcs = entry.dn.scan(/dc\s*=\s*([^,\s]+)/i)
    result[:name]    = fqdn ? ([cn]+dcs).join('.') : cn
    result[:parent] = get_parent_from_entry(entry) if parent_attribute
    result[:classes] = get_classes_from_entry(entry)
    result[:stacked] = get_stacked_values_from_entry(entry)
    result[:parameters] = get_parameters_from_entry(entry)

    result[:environment] = result[:parameters]["environment"] if result[:parameters]["environment"]

    result[:stacked_parameters] = {}

    if result[:stacked]
      result[:stacked].each do |value|
        param = value.split('=', 2)
        result[:stacked_parameters][param[0]] = param[1]
      end
    end

    if result[:stacked_parameters]
      result[:stacked_parameters].each do |param, value|
        result[:parameters][param] = value unless result[:parameters].include?(param)
      end
    end

    result[:parameters] = convert_parameters(result[:parameters])

    result
  end

  # Default to all attributes.
  def search_attributes
    ldapattrs = Puppet[:ldapattrs]

    # results in everything getting returned
    return nil if ldapattrs == "all"

    search_attrs = class_attributes + ldapattrs.split(/\s*,\s*/)

    if pattr = parent_attribute
      search_attrs << pattr
    end

    search_attrs
  end

  # The ldap search filter to use.
  def search_filter(name)
    filter = Puppet[:ldapstring]

    if filter.include? "%s"
      # Don't replace the string in-line, since that would hard-code our node
      # info.
      filter = filter.gsub('%s', name)
    end
    filter
  end

  private

  # Add our hash of ldap information to the node instance.
  def add_to_node(node, information)
    node.classes = information[:classes].uniq unless information[:classes].nil? or information[:classes].empty?
    node.parameters = information[:parameters] unless information[:parameters].nil? or information[:parameters].empty?
    node.environment = information[:environment] if information[:environment]
  end

  def convert_parameters(parameters)
    result = {}
    parameters.each do |param, value|
      if value.is_a?(Array)
        result[param] = value.collect { |v| convert(v) }
      else
        result[param] = convert(value)
      end
    end
    result
  end

  # Convert any values if necessary.
  def convert(value)
    case value
    when Integer, Fixnum, Bignum; value
    when "true"; true
    when "false"; false
    else
      value
    end
  end

  # Find information for our parent and merge it into the current info.
  def find_and_merge_parent(parent, information)
    parent_info = name2hash(parent) || raise(Puppet::Error.new("Could not find parent node '#{parent}'"))
    information[:classes] += parent_info[:classes]
    parent_info[:parameters].each do |param, value|
      # Specifically test for whether it's set, so false values are handled correctly.
      information[:parameters][param] = value unless information[:parameters].include?(param)
    end
    information[:environment] ||= parent_info[:environment]
    parent_info[:parent]
  end

  # Take a name and a hash, and return a node instance.
  def info2node(name, info)
    node = Puppet::Node.new(name)

    add_to_node(node, info)

    node.fact_merge

    node
  end

  def merge_parent(info)
    parent = info[:parent]

    # Preload the parent array with the node name.
    parents = [info[:name]]
    while parent
      raise ArgumentError, "Found loop in LDAP node parents; #{parent} appears twice" if parents.include?(parent)
      parents << parent
      parent = find_and_merge_parent(parent, info)
    end

    info
  end

  def get_classes_from_entry(entry)
    result = class_attributes.inject([]) do |array, attr|
      if values = entry.vals(attr)
        values.each do |v| array << v end
      end
      array
    end
    result.uniq
  end

  def get_parameters_from_entry(entry)
    stacked_params = stacked_attributes
    entry.to_hash.inject({}) do |hash, ary|
      unless stacked_params.include?(ary[0]) # don't add our stacked parameters to the main param list
        if ary[1].length == 1
          hash[ary[0]] = ary[1].shift
        else
          hash[ary[0]] = ary[1]
        end
      end
      hash
    end
  end

  def get_parent_from_entry(entry)
    pattr = parent_attribute

    return nil unless values = entry.vals(pattr)

    if values.length > 1
      raise Puppet::Error,
        "Node entry #{entry.dn} specifies more than one parent: #{values.inspect}"
    end
    return(values.empty? ? nil : values.shift)
  end

  def get_stacked_values_from_entry(entry)
    stacked_attributes.inject([]) do |result, attr|
      if values = entry.vals(attr)
        result += values
      end
      result
    end
  end
end
