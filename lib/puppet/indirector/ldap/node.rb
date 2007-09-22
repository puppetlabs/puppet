require 'puppet/indirector/ldap'

class Puppet::Indirector::Ldap::Node < Puppet::Indirector::Ldap
    desc "Search in LDAP for node configuration information."

    # The attributes that Puppet class information is stored in.
    def class_attributes
        Puppet[:ldapclassattrs].split(/\s*,\s*/)
    end

    # Look for our node in ldap.
    def find(name)
        unless ary = ldapsearch(name)
            return nil
        end
        parent, classes, parameters = ary

        while parent
            parent, tmpclasses, tmpparams = ldapsearch(parent)
            classes += tmpclasses if tmpclasses
            tmpparams.each do |param, value|
                # Specifically test for whether it's set, so false values are handled
                # correctly.
                parameters[param] = value unless parameters.include?(param)
            end
        end

        node = Puppet::Node.new(name, :classes => classes, :source => "ldap", :parameters => parameters)
        node.fact_merge
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

    # Process the found entry.  We assume that we don't just want the
    # ldap object.
    def process(entry)
        raise Puppet::DevError, "The 'process' method has not been overridden for the LDAP terminus for %s" % self.name
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
end
