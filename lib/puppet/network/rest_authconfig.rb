require 'puppet/network/authconfig'

module Puppet
    class Network::RestAuthConfig < Network::AuthConfig

        attr_accessor :rights

        DEFAULT_ACL = [
            { :acl => "~ ^\/catalog\/([^\/]+)$", :method => :find, :allow => '$1', :authenticated => true },
            # this one will allow all file access, and thus delegate
            # to fileserver.conf
            { :acl => "/file" },
            { :acl => "/certificate_revocation_list/ca", :method => :find, :authenticated => true },
            { :acl => "/report", :method => :save, :authenticated => true },
            { :acl => "/certificate/ca", :method => :find, :authenticated => false },
            { :acl => "/certificate/", :method => :find, :authenticated => false },
            { :acl => "/certificate_request", :method => [:find, :save], :authenticated => false },
        ]

        def self.main
            add_acl = @main.nil?
            super
            @main.insert_default_acl if add_acl and !@main.exists?
            @main
        end

        # check wether this request is allowed in our ACL
        # raise an Puppet::Network::AuthorizedError if the request
        # is denied.
        def allowed?(request)
            read()

            # we're splitting the request in part because
            # fail_on_deny could as well be called in the XMLRPC context
            # with a ClientRequest.
            @rights.fail_on_deny(build_uri(request),
                                    :node => request.node,
                                    :ip => request.ip,
                                    :method => request.method,
                                    :environment => request.environment,
                                    :authenticated => request.authenticated)
        end

        def initialize(file = nil, parsenow = true)
            super(file || Puppet[:rest_authconfig], parsenow)

            # if we didn't read a file (ie it doesn't exist)
            # make sure we can create some default rights
            @rights ||= Puppet::Network::Rights.new
        end

        def parse()
            super()
            insert_default_acl
        end

        # force regular ACLs to be present
        def insert_default_acl
            DEFAULT_ACL.each do |acl|
                unless rights[acl[:acl]]
                    Puppet.info "Inserting default '#{acl[:acl]}'(%s) acl because %s" % [acl[:authenticated] ? "auth" : "non-auth" , ( !exists? ? "#{Puppet[:rest_authconfig]} doesn't exist" : "none where found in '#{@file}'")]
                    mk_acl(acl)
                end
            end
            # queue an empty (ie deny all) right for every other path
            # actually this is not strictly necessary as the rights system
            # denies not explicitely allowed paths
            unless rights["/"]
                rights.newright("/")
                rights.restrict_authenticated("/", :any)
            end
        end

        def mk_acl(acl)
            @rights.newright(acl[:acl])
            @rights.allow(acl[:acl], acl[:allow] || "*")

            if method = acl[:method]
                method = [method] unless method.is_a?(Array)
                method.each { |m| @rights.restrict_method(acl[:acl], m) }
            end
            @rights.restrict_authenticated(acl[:acl], acl[:authenticated]) unless acl[:authenticated].nil?
        end

        def build_uri(request)
            "/#{request.indirection_name}/#{request.key}"
        end
    end
end
