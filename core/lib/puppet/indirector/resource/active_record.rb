require 'puppet/indirector/active_record'
require 'puppet/indirector/resource/validator'

class Puppet::Resource::ActiveRecord < Puppet::Indirector::ActiveRecord
  include Puppet::Resource::Validator

  desc "A component of ActiveRecord storeconfigs. ActiveRecord-based storeconfigs
    and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"

  def initialize
    Puppet.deprecation_warning "ActiveRecord-based storeconfigs and inventory are deprecated. See http://links.puppetlabs.com/activerecord-deprecation"
    super
  end

  def search(request)
    type   = request_to_type_name(request)
    host   = request.options[:host]
    filter = request.options[:filter]

    if filter and filter[1] =~ /^(and|or)$/i then
      raise Puppet::Error, "Complex search on StoreConfigs resources is not supported"
    end

    query = build_active_record_query(type, host, filter)
    Puppet::Rails::Resource.find(:all, query)
  end

  private
  def request_to_type_name(request)
    request.key.split('/', 2)[0] or
      raise "No key found in the request, failing: #{request.inspect}"
  end

  def filter_to_active_record(filter)
    # Don't call me if you don't have a filter, please.
    filter.is_a?(Array) or raise ArgumentError, "active record filters must be arrays"
    a, op, b = filter

    case op
    when /^(and|or)$/i then
      extra = []
      first, args = filter_to_active_record a
      extra += args

      second, args = filter_to_active_record b
      extra += args

      return "(#{first}) #{op.upcase} (#{second})", extra

    when "==", "!=" then
      op = '=' if op == '=='    # SQL, yayz!
      case a
      when "title" then
        return "title #{op} ?", [b]

      when "tag" then
        return "puppet_tags.name #{op} ?", [b]

      else
        return "param_names.name = ? AND param_values.value #{op} ?", [a, b]
      end

    else
      raise ArgumentError, "unknown operator #{op.inspect} in #{filter.inspect}"
    end
  end

  def build_active_record_query(type, host, filter)
    raise Puppet::DevError, "Cannot collect resources for a nil host" unless host

    search = "(exported=? AND restype=?)"
    arguments = [true, type]

    if filter then
      sql, values = filter_to_active_record(filter)
      search    += " AND #{sql}"
      arguments += values
    end

    # note: we're not eagerly including any relations here because it can
    # create large numbers of objects that we will just throw out later.  We
    # used to eagerly include param_names/values but the way the search filter
    # is built ruined those efforts and we were eagerly loading only the
    # searched parameter and not the other ones.
    query = {}
    case search
    when /puppet_tags/
      query = { :joins => { :resource_tags => :puppet_tag } }
    when /param_name/
      query = { :joins => { :param_values => :param_name } }
    end

    # We're going to collect objects from rails, but we don't want any
    # objects from this host.
    if host = Puppet::Rails::Host.find_by_name(host)
      search += " AND (host_id != ?)"
      arguments << host.id
    end

    query[:conditions] = [search, *arguments]

    query
  end
end
