require 'puppet/node'
require 'puppet/indirector/ldap'

class Puppet::Node::Ldap < Puppet::Indirector::Ldap
    desc "Search in LDAP for node configuration information.  See
    the `LdapNodes`:trac: page for more information.  This will first
    search for whatever the certificate name is, then (if that name
    contains a '.') for the short name, then 'default'."

    # The attributes that Puppet class information is stored in.
    def class_attributes
        # LAK:NOTE See http://snurl.com/21zf8  [groups_google_com] 
        x = Puppet[:ldapclassattrs].split(/\s*,\s*/)
    end

    # Look for our node in ldap.
    def find(request)
        names = [request.key]
        if request.key.include?(".") # we assume it's an fqdn
            names << request.key.sub(/\..+/, '')
        end
        names << "default"

        information = nil
        names.each do |name|
            break if information = entry2hash(name)
        end
        return nil unless information

        name = request.key

        node = Puppet::Node.new(name)

        add_to_node(node, information)

        return node
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

    # Process the found entry.  We assume that we don't just want the
    # ldap object.
    def process(name, entry)
        result = {}
        if pattr = parent_attribute
            if values = entry.vals(pattr)
                if values.length > 1
                    raise Puppet::Error,
                        "Node %s has more than one parent: %s" % [name, values.inspect]
                end
                unless values.empty?
                    result[:parent] = values.shift
                end
            end
        end

        result[:classes] = []
        class_attributes.each { |attr|
            if values = entry.vals(attr)
                values.each do |v| result[:classes] << v end
            end
        }

        result[:stacked] = []
        stacked_attributes.each { |attr|
            if values = entry.vals(attr)
                result[:stacked] = result[:stacked] + values
            end
        }
        

        result[:parameters] = entry.to_hash.inject({}) do |hash, ary|
            if ary[1].length == 1
                hash[ary[0]] = ary[1].shift
            else
                hash[ary[0]] = ary[1]
            end
            hash
        end

        result[:environment] = result[:parameters]["environment"] if result[:parameters]["environment"]

        return result
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
        information[:stacked_parameters] = {}

        parent_info = nil
        parent = information[:parent]
        parents = [node.name]
        while parent
            if parents.include?(parent)
                raise ArgumentError, "Found loop in LDAP node parents; %s appears twice" % parent
            end
            parents << parent
            parent = find_and_merge_parent(parent, information)
        end

        if information[:stacked]
            information[:stacked].each do |value|
                param = value.split('=', 2)
                information[:stacked_parameters][param[0]] = param[1]
            end
        end

        if information[:stacked_parameters]
            information[:stacked_parameters].each do |param, value|
                information[:parameters][param] = value unless information[:parameters].include?(param)
            end
        end

        node.classes = information[:classes].uniq unless information[:classes].nil? or information[:classes].empty?
        node.parameters = information[:parameters] unless information[:parameters].nil? or information[:parameters].empty?
        node.environment = information[:environment] if information[:environment]
        node.fact_merge
    end

    # Find information for our parent and merge it into the current info.
    def find_and_merge_parent(parent, information)
        parent_info = nil
        ldapsearch(parent) { |entry| parent_info = process(parent, entry) }

        unless parent_info
            raise Puppet::Error.new("Could not find parent node '%s'" % parent)
        end
        information[:classes] += parent_info[:classes]
        parent_info[:stacked].each do |value|
            param = value.split('=', 2)
            information[:stacked_parameters][param[0]] = param[1]
        end
        parent_info[:parameters].each do |param, value|
            # Specifically test for whether it's set, so false values are handled
            # correctly.
            information[:parameters][param] = value unless information[:parameters].include?(param)
        end

        information[:environment] ||= parent_info[:environment]

        parent_info[:parent]
    end
end
