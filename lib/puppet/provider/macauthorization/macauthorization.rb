require 'facter/util/plist'
require 'puppet'

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
                                    :comment => "comment",
                                    # :group => "group,"
                                    :shared => "shared",
                                    :mechanisms => "mechanisms"}
                              
    NativeToPuppetAttributeMap = {  "allow-root" => :allow_root,
                                    "authenticate-user" => :authenticate_user,
                                    "class" => :authclass,
                                    "comment" => :comment,
                                    "shared" => :shared,
                                    "mechanisms" => :mechanisms, }

    mk_resource_methods
    
    class << self
        attr_accessor :parsed_auth_db
        attr_accessor :rights
        attr_accessor :rules
        attr_accessor :comments
    end
    
    def self.prefetch(resources)
        # Puppet.notice("self.prefetch.")
        self.populate_rules_rights
    end
    
    def self.instances
        # Puppet.notice("self.instances")
        self.populate_rules_rights
        self.parsed_auth_db.collect do |k,v|
            new(:name => k)  # doesn't seem to matter if I fill them in?
        end
    end
    
    def self.populate_rules_rights
        # Puppet.notice("self.populate_rules_rights")
        auth_plist = Plist::parse_xml("/etc/authorization")
        if not auth_plist
            Puppet.notice("This should be an error nigel")
        end
        self.rights = auth_plist["rights"]
        self.rules = auth_plist["rules"]
        self.parsed_auth_db = self.rights
        self.parsed_auth_db.merge(self.rules)
    end
    
    def initialize(resource)
        Puppet.notice "initialize"
        super
    end
    
    def flush
        # Puppet.notice("flush called")
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
        
        # specified_values.each_pair do |k,v|
        #     Puppet.notice "specified_values: #{k} => #{v}"
        # end
        # current_values.each_pair do |k,v|
        #     Puppet.notice "current values: #{k} => #{v}"
        # end
        
        # take the current values, merge the specified values to obtain a complete
        # description of the new values.
        new_values = current_values.merge(specified_values)
        new_values.each_pair do |k,v|
            Puppet.notice "new values: #{k} => #{v}"
        end
    end
    
    def flush_rule
        
    end
    
    def convert_plist_to_native_attributes(propertylist)
        propertylist.each_pair do |key, value|
            if PuppetToNativeAttributeMap.has_key?(key)
                new_key = PuppetToNativeAttributeMap[key]
                propertylist[new_key] = value
                propertylist.delete(key)
            end
        end
        propertylist
    end
    
    # # Look up the current status.
    # def properties
    #     if @property_hash.empty?
    #         @property_hash = status || {}
    #         if @property_hash.empty?
    #             @property_hash[:ensure] = :absent
    #         else
    #             @resource.class.validproperties.each do |name|
    #                 @property_hash[name] ||= :absent
    #             end
    #         end
    # 
    #     end
    #     @property_hash.dup
    # end
    
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
        
        return nil if not self.class.parsed_auth_db.has_key?(resource_name) # error!!
       
        if PuppetToNativeAttributeMap.has_key?(attribute)
           native_attribute = PuppetToNativeAttributeMap[attribute]
           # Puppet.notice "attribute set from: #{attribute} to #{PuppetToNativeAttributeMap[attribute]}"
        else
            native_attribute = attribute
        end
        
        if self.class.parsed_auth_db[resource_name].has_key?(native_attribute)
            value = self.class.parsed_auth_db[resource_name][native_attribute]
            # Puppet.notice "retrieve value has found: #{value} of kind #{value.class}"
            if value == "true" or value == true or value == :true
                value = :true
            elsif value == "false" or value == false or value == :false
                value = :false
            end
            @property_hash[attribute] = value
            # @property_hash.each_pair do |k,v|
            #     next if k == :ensure
            #     Puppet.notice "NBK: prop hash for #{k} is #{v}"
            # end
            return value
        else
            @property_hash.delete(attribute) # do I do this here?
            return 
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
            raise Puppet::Error.new("wtf mate?")
        end
    end
    
    def auth_type=(value)
        Puppet.notice "set auth_type="
        @property_hash[:auth_type] = value
    end
    
end