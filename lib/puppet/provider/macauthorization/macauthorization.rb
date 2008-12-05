require 'facter/util/plist'
require 'puppet'
require 'tempfile'

Puppet::Type.type(:macauthorization).provide :macauthorization, :parent => Puppet::Provider do
# Puppet::Type.type(:macauthorization).provide :macauth  do
    desc "Manage Mac OS X authorization database."

    commands :security => "/usr/bin/security"
    
    confine :operatingsystem => :darwin
    defaultfor :operatingsystem => :darwin
    
    AuthorizationDB = "/etc/authorization"
    
    @rights = {}
    @rules = {}
    @parsed_auth_db = {}
    @comment = ""  # Not implemented yet. Is there any real need to?
    
    # This map exists due to the use of hyphens and reserved words in
    # the authorization schema.
    PuppetToNativeAttributeMap = {  :allow_root => "allow-root",
                                    :authenticate_user => "authenticate-user",                                    
                                    :auth_class => "class",
                                    :k_of_n => "k-of-n",
                                    }

    mk_resource_methods
    
    class << self
        attr_accessor :parsed_auth_db
        attr_accessor :rights
        attr_accessor :rules
        attr_accessor :comments  # Not implemented yet. Is there any real need to?
    end
    
    def self.prefetch(resources)
        self.populate_rules_rights
    end
    
    def self.instances
        self.populate_rules_rights
        self.parsed_auth_db.collect do |k,v|
            new(:name => k)
        end
    end
    
    def self.populate_rules_rights
        auth_plist = Plist::parse_xml(AuthorizationDB)
        if not auth_plist
            raise Puppet::Error.new("Unable to parse authorization db at #{AuthorizationDB}")
        end
        self.rights = auth_plist["rights"].dup
        self.rules = auth_plist["rules"].dup
        self.parsed_auth_db = self.rights.dup
        self.parsed_auth_db.merge!(self.rules.dup)
    end
    
    def initialize(resource)
        if self.class.parsed_auth_db.nil?
            self.class.prefetch
        end
        super
    end
    
    
    def create
        # we just fill the @property_hash in here and let the flush method deal with it
        new_values = {}
        Puppet::Type.type(resource.class.name).validproperties.each do |property|
            next if property == :ensure
            if value = resource.should(property) and value != ""
                new_values[property] = value
            end
        end
        @property_hash = new_values.dup
    end

    def destroy
        # We explicitly delete here rather than in the flush method.
        case resource[:auth_type]
        when :right
            destroy_right
        when :rule
            destroy_rule
        else
            raise Puppet::Error("You must specify the auth_type when removing macauthorization resources.")
        end
    end
    
    def destroy_right
        security :authorizationdb, :remove, resource[:name]
    end
    
    def destroy_rule
        authdb = Plist::parse_xml(AuthorizationDB)
        authdb_rules = authdb["rules"].dup
        if authdb_rules[resource[:name]]
            authdb["rules"].delete(resource[:name])
            Plist::Emit.save_plist(authdb, AuthorizationDB)
        end
    end
    
    def exists?
        if self.class.parsed_auth_db.has_key?(resource[:name])
            # return :present
            return true
        else
            return false
        end
    end
    
    
    def flush
        if resource[:ensure] != :absent  # deletion happens in the destroy methods
            case resource[:auth_type]
            when :right
                flush_right
            when :rule
                flush_rule
            else
                raise Puppet::Error.new("flushing something that isn't a right or a rule.")
            end
            @property_hash.clear
        end
    end
    
    def flush_right
        # first we re-read the right just to make sure we're in sync for values
        # that weren't specified in the manifest. As we're supplying the whole
        # plist when specifying the right it seems safest to be paranoid.
        cmds = [] << :security << "authorizationdb" << "read" << resource[:name]
        output = execute(cmds, :combine => false)
        current_values = Plist::parse_xml(output)
        if current_values.nil?
            current_values = {}
        end
        specified_values = convert_plist_to_native_attributes(@property_hash)

        # take the current values, merge the specified values to obtain a complete
        # description of the new values.
        new_values = current_values.merge(specified_values)
        set_right(resource[:name], new_values)
    end
    
    def flush_rule
        authdb = Plist::parse_xml(AuthorizationDB)
        authdb_rules = authdb["rules"].dup
        current_values = {}
        if authdb_rules[resource[:name]]
            current_values = authdb_rules[resource[:name]]
        end
        specified_values = convert_plist_to_native_attributes(@property_hash)
        new_values = current_values.merge(specified_values)
        set_rule(resource[:name], new_values)
    end
    
    def set_right(name, values)
        # Both creates and modifies rights as it simply overwrites them.
        # The security binary only allows for writes using stdin, so we
        # dump the values to a tempfile.
        values = convert_plist_to_native_attributes(values)
        tmp = Tempfile.new('puppet_macauthorization')
        begin
            # tmp.flush
            Plist::Emit.save_plist(values, tmp.path)
            # tmp.flush
            cmds = [] << :security << "authorizationdb" << "write" << name
            output = execute(cmds, :combine => false, :stdinfile => tmp.path.to_s)
        ensure
            tmp.close
            tmp.unlink
        end
    end
    
    def set_rule(name, values)
        # Both creates and modifies rules as it overwrites the entry in the rules
        # dictionary.
        # Unfortunately the security binary doesn't support modifying rules at all
        # so we have to twiddle the whole plist... :( See Apple Bug #6386000
        values = convert_plist_to_native_attributes(values)
        authdb = Plist::parse_xml(AuthorizationDB)
        authdb["rules"][name] = values

        begin
            Plist::Emit.save_plist(authdb, AuthorizationDB)
        rescue
            raise Puppet::Error.new("Couldn't write to authorization db at #{AuthorizationDB}")
        end
    end
    
    def convert_plist_to_native_attributes(propertylist)
        # This mainly converts the keys from the puppet attributes to the 'native'
        # ones, but also enforces that the keys are all Strings rather than Symbols
        # so that any merges of the resultant Hash are sane.
        newplist = {}
        propertylist.each_pair do |key, value|
            next if key == :ensure
            next if key == :auth_type
            new_key = key
            if PuppetToNativeAttributeMap.has_key?(key)
                new_key = PuppetToNativeAttributeMap[key].to_s
            elsif not key.is_a?(String)
                new_key = key.to_s
            end
            newplist[new_key] = value
        end
        newplist
    end
    
    def retrieve_value(resource_name, attribute)
        
        if not self.class.parsed_auth_db.has_key?(resource_name)
            raise Puppet::Error.new("Unable to find resource #{resource_name} in authorization db.")
        end
       
        if PuppetToNativeAttributeMap.has_key?(attribute)
            native_attribute = PuppetToNativeAttributeMap[attribute]
        else
            native_attribute = attribute.to_s
        end

        if self.class.parsed_auth_db[resource_name].has_key?(native_attribute)
            value = self.class.parsed_auth_db[resource_name][native_attribute]
            case value
            when true, "true", :true
                value = :true
            when false, "false", :false
                value = :false
            end

            @property_hash[attribute] = value
            return value
        else
            @property_hash.delete(attribute)
            return ""
        end
    end
    
    def allow_root
        retrieve_value(resource[:name], :allow_root)
    end
    
    def allow_root=(value)
        @property_hash[:allow_root] = value
    end
    
    def authenticate_user
        retrieve_value(resource[:name], :authenticate_user)
    end
    
    def authenticate_user= (dosync)
        @property_hash[:authenticate_user] = value
    end
        
    def auth_class
        retrieve_value(resource[:name], :auth_class)
    end
    
    def auth_class=(value)
        @property_hash[:auth_class] = value
    end
    
    def comment
        retrieve_value(resource[:name], :comment)
    end
    
    def comment=(value)
        @property_hash[:comment] = value
    end
    
    def group
        retrieve_value(resource[:name], :group)
    end
    
    def group=(value)
        @property_hash[:group] = value
    end
    
    def k_of_n
        retrieve_value(resource[:name], :k_of_n)
    end
    
    def k_of_n=(value)
        @property_hash[:k_of_n] = value
    end

    def mechanisms
        retrieve_value(resource[:name], :mechanisms)
    end

    def mechanisms=(value)
        @property_hash[:mechanisms] = value
    end
    
    def rule
        retrieve_value(resource[:name], :rule)
    end

    def rule=(value)
        @property_hash[:rule] = value
    end
    
    def shared
        retrieve_value(resource[:name], :shared)
    end
    
    def shared=(value)
        @property_hash[:shared] = value
    end
    
    def auth_type
        if resource.should(:auth_type) != nil
            return resource.should(:auth_type)
        elsif self.exists?
            # this is here just for ralsh, so it can work out what type it is.
            if self.class.rights.has_key?(resource[:name])
                return :right
            elsif self.class.rules.has_key?(resource[:name])
                return :rule
            else
                raise Puppet::Error.new("Unable to determine if macauthorization type: #{resource[:name]} is a right or a rule.")
            end
        else
            raise Puppet::Error.new("You must specify the auth_type for new macauthorization resources.")
        end
    end
    
    def auth_type=(value)
        @property_hash[:auth_type] = value
    end
    
end