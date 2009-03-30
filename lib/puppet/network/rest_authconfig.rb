require 'puppet/network/authconfig'

module Puppet
    class Network::RestAuthConfig < Network::AuthConfig

        attr_accessor :rights

        DEFAULT_ACL = {
            :facts =>   { :acl => "/facts", :method => [:save, :find] },
            :catalog => { :acl => "/catalog", :method => :find },
            # this one will allow all file access, and thus delegate
            # to fileserver.conf
            :file =>    { :acl => "/file" },
            :cert =>    { :acl => "/certificate", :method => :find },
            :reports => { :acl => "/report", :method => :save }
        }

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

            @rights.fail_on_deny(build_uri(request),
                                    :node => request.node,
                                    :ip => request.ip,
                                    :method => request.method,
                                    :environment => request.environment)
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
            DEFAULT_ACL.each do |name, acl|
                unless rights[acl[:acl]]
                    Puppet.warning "Inserting default '#{acl[:acl]}' acl because none were found in '%s'" % ( @file || "no file configured")
                    mk_acl(acl[:acl], acl[:method])
                end
            end
            # queue an empty (ie deny all) right for every other path
            # actually this is not strictly necessary as the rights system
            # denies not explicitely allowed paths
            rights.newright("/") unless rights["/"]
        end

        def mk_acl(path, method = nil)
            @rights.newright(path)
            @rights.allow(path, "*")

            if method
                method = [method] unless method.is_a?(Array)
                method.each { |m| @rights.restrict_method(path, m) }
            end
        end

        def build_uri(request)
            "/#{request.indirection_name}/#{request.key}"
        end
    end
end
