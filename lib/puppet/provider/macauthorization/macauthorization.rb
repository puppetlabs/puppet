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
    @comment = ""
    
    PuppetToNativeAttributeMap = {  :allow_root => "allow-root",
                                    :authenticate_user => "authenticate-user",                                    
                                    :authclass => "class",
                                    :k_of_n => "k-of-n",
                                    # :comment => "comment",
                                    # :group => "group,"
                                    # :shared => "shared",
                                    # :mechanisms => "mechanisms"
                                    }
                              
    NativeToPuppetAttributeMap = {  "allow-root" => :allow_root,
                                    "authenticate-user" => :authenticate_user,
                                    # "class" => :authclass,
                                    # "comment" => :comment,
                                    # "shared" => :shared,
                                    # "mechanisms" => :mechanisms, 
                                    }

    mk_resource_methods
    
    class << self
        attr_accessor :parsed_auth_db
        attr_accessor :rights
        attr_accessor :rules
        attr_accessor :comments
    end
    
    def self.prefetch(resources)
        Puppet.notice("self.prefetch.")
        self.populate_rules_rights
    end
    
    def self.instances
        Puppet.notice("self.instances")
        self.populate_rules_rights
        self.parsed_auth_db.collect do |k,v|
            new(:name => k)  # doesn't seem to matter if I fill them in?
        end
    end
    
    def self.populate_rules_rights
        Puppet.notice("self.populate_rules_rights")
        auth_plist = Plist::parse_xml("/etc/authorization")
        if not auth_plist
            Puppet.notice("This should be an error nigel")
        end
        self.rights = auth_plist["rights"].dup
        self.rules = auth_plist["rules"].dup
        self.parsed_auth_db = self.rights.dup
        self.parsed_auth_db.merge!(self.rules.dup)
    end
    
    def initialize(resource)
        Puppet.notice "initialize"
        self.class.populate_rules_rights
        super
    end
    
    def flush
        case resource[:auth_type]
        when :right
            flush_right
        when :rule
            flush_rule
        else
            raise Puppet::Error("flushing something that isn't a right or a rule.")
        end
        @property_hash.clear # huh? do I have to? 
    end
    
    def flush_right
        # first we re-read the right just to make sure we're in sync for values
        # that weren't specified in the manifest. As we're supplying the whole
        # plist when specifying the right it seems safest to be paranoid.
        cmds = [] << :security << "authorizationdb" << "read" << resource[:name]
        output = execute(cmds, :combine => false)
        current_values = Plist::parse_xml(output)
        specified_values = convert_plist_to_native_attributes(@property_hash)

        # take the current values, merge the specified values to obtain a complete
        # description of the new values.
        new_values = current_values.merge(specified_values)
        Puppet.notice "new values: #{new_values}"
        
        # the security binary only allows for writes using stdin, so we dump this
        # to a tempfile.
        tmp = Tempfile.new('puppet_macauthorization')
        begin
            tmp.flush
            Plist::Emit.save_plist(new_values, tmp.path)
            # tmp.flush
            cmds = [] << :security << "authorizationdb" << "write" << resource[:name]
            output = execute(cmds, :stdinfile => tmp.path.to_s)
        ensure
            tmp.close
            tmp.unlink
        end
    end
    
    def flush_rule
        # unfortunately the security binary doesn't support modifying rules at all
        # so we have to twiddle the whole plist... :( See Apple Bug #6386000
        authdb = Plist::parse_xml(AuthorizationDB)
        authdb_rules = authdb["rules"].dup
        current_values = []
        if authdb_rules[resource[:name]]
            current_values = authdb_rules[resource[:name]]
        end
        specified_values = convert_plist_to_native_attributes(@property_hash)
        new_values = current_values.merge(specified_values)
        authdb["rules"][resource[:name]] = new_values
        begin
            Plist::Emit.save_plist(authdb, AuthorizationDB)
        rescue # what do I rescue here? TODO
            raise Puppet::Error.new("couldn't write to authorizationdb")
        end
    end
    
    # This mainly converts the keys from the puppet attributes to the 'native'
    # ones, but also enforces that the keys are all Strings rather than Symbols
    # so that any merges of the resultant Hash are sane.
    def convert_plist_to_native_attributes(propertylist)
        propertylist.each_pair do |key, value|
            new_key = nil
            if PuppetToNativeAttributeMap.has_key?(key)
                new_key = PuppetToNativeAttributeMap[key].to_s
            elsif not key.is_a?(String)
                new_key = key.to_s
            end
            if not new_key.nil?
                propertylist.delete(key)
                propertylist[new_key] = value
            end
        end
        propertylist
    end
    
    def create
        Puppet.notice "creating #{resource[:name]}"
        return :true
    end

    def destroy
        Puppet.notice "destroying #{resource[:name]}"
    end

    def exists?
        if self.class.parsed_auth_db.has_key?(resource[:name])
            :true
        else
            :false
        end
    end
    
    def retrieve_value(resource_name, attribute)
        # Puppet.notice "retrieve #{attribute} from #{resource_name}"
        
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
        retrieve_value(resource[:name], :authclass)
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
        Puppet.notice "setting shared to: #{value} of kind #{value.class}"
        @property_hash[:shared] = value
    end
    
    def auth_type
        if self.class.rights.has_key?(resource[:name])
            return :right
        elsif self.class.rules.has_key?(resource[:name])
            return :rule
        else
            Puppet.notice "self.class.rights.keys #{self.class.rights.keys}"
            Puppet.notice "self.class.rules.keys #{self.class.rules.keys}"            
            raise Puppet::Error.new("wtf mate?")
        end
    end
    
    def auth_type=(value)
        Puppet.notice "set auth_type="
        @property_hash[:auth_type] = value
    end
    
end