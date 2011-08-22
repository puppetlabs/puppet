require 'puppet/indirector/active_record'

class Puppet::Resource::ActiveRecord < Puppet::Indirector::ActiveRecord
  def search(request)
    type   = request_to_type(request)
    host   = request.options[:host]
    filter = request.options[:filter]

    query = build_active_record_query(type, host, filter)
    Puppet::Rails::Resource.find(:all, query)
  end

  private
  def request_to_type(request)
    name = request.key.split('/', 2)[0]
    Puppet::Type.type(name) or raise Puppet::Error, "Could not find type #{name}"
  end

  def build_active_record_query(type, host, filter)
    raise Puppet::DevError, "Cannot collect resources for a nil host" unless host

    search = "(exported=? AND restype=?)"
    arguments = [true, type.name]

    # REVISIT: This cannot stand.  We need to abstract the search language
    # away here, so that we can unbind our ActiveRecord schema and our parser
    # of search inputs from each other. --daniel 2011-08-23
    search += " AND (#{filter})" if filter

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
