#  Created by Jeff McCune on 2007-07-22
#  Copyright (c) 2007. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation (version 2 of the License)
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston MA  02110-1301 USA

require 'puppet'
require 'puppet/provider/nameservice'

class Puppet::Provider::NameService
class DirectoryService < Puppet::Provider::NameService
    # JJM: Dive into the eigenclass
    class << self
        # JJM: This allows us to pass information when calling
        #      Puppet::Type.type
        #  e.g. Puppet::Type.type(:user).provide :directoryservice, :ds_path => "Users"
        #  This is referenced in the get_ds_path class method
        attr_writer :ds_path
    end

    # JJM 2007-07-24: Not yet sure what initvars() does.  I saw it in netinfo.rb
    # I do know, however, that it makes methods "work"  =)
    # e.g. addcmd isn't available if this method call isn't present.
    #
    # JJM: Also, where this method is defined seems to impact the visibility
    #   of methods.  If I put initvars after commands, confine and defaultfor,
    #   then getinfo is called from the parent class, not this class.
    initvars()
    
    commands :dscl => "/usr/bin/dscl"
    confine :operatingsystem => :darwin
    # JJM FIXME: This will need to be the default around October 2007.
    # defaultfor :operatingsystem => :darwin


    # JJM 2007-07-25: This map is used to map NameService attributes to their
    #     corresponding DirectoryService attribute names.
    #     See: http://images.apple.com/server/docs/Open_Directory_v10.4.pdf
    # JJM: Note, this is de-coupled from the Puppet::Type, and must
    #     be actively maintained.  There may also be collisions with different
    #     types (Users, Groups, Mounts, Hosts, etc...)
    @@ds_to_ns_attribute_map = {
        'RecordName' => :name,
        'PrimaryGroupID' => :gid,
        'NFSHomeDirectory' => :home,
        'UserShell' => :shell,
        'UniqueID' => :uid,
        'RealName' => :comment,
        'Password' => :password,
    }
    # JJM The same table as above, inverted.
    @@ns_to_ds_attribute_map = {
        :name => 'RecordName',
        :gid => 'PrimaryGroupID',
        :home => 'NFSHomeDirectory',
        :shell => 'UserShell',
        :uid => 'UniqueID',
        :comment => 'RealName',
        :password => 'Password',
    }
    
    def self.instances
        # JJM Class method that provides an array of instance objects of this
        #     type.
        
        # JJM: Properties are dependent on the Puppet::Type we're managine.
        type_property_array = [:name] + @resource_type.validproperties
        # JJM: No sense reporting the password.  It's hashed.
        type_property_array.delete(:password) if type_property_array.include? :password
        
        # Create a new instance of this Puppet::Type for each object present
        #    on the system.
        list_all_present.collect do |name_string|
            self.new(single_report(name_string, *type_property_array))
        end
    end
    
    def self.get_ds_path
        # JJM: 2007-07-24 This method dynamically returns the DS path we're concerned with.
        #      For example, if we're working with an user type, this will be /Users
        #      with a group type, this will be /Groups.
        #   @ds_path is an attribute of the class itself.  
        if defined? @ds_path
            return @ds_path
        else
            # JJM: "Users" or "Groups" etc ...  (Based on the Puppet::Type)
            #       Remember this is a class method, so self.class is Class
            #       Also, @resource_type seems to be the reference to the
            #       Puppet::Type this class object is providing for.
            return @resource_type.name.to_s.capitalize + "s"
        end
    end

    def self.list_all_present
        # JJM: List all objects of this Puppet::Type already present on the system.
        begin
            dscl_output = execute(get_exec_preamble("-list"))
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not get %s list from DirectoryService" % [ @resource_type.name.to_s ]
        end
        return dscl_output.split("\n")
    end
    
    def self.single_report(resource_name, *type_properties)
        # JJM 2007-07-24:
        #     Given a the name of an object and a list of properties of that
        #     object, return all property values in a hash.
        #     
        #     This class method returns nil if the object doesn't exist
        #     Otherwise, it returns a hash of the object properties.
        
        all_present_str_array = list_all_present()
        
        # JJM: Return nil if the named object isn't present.
        return nil unless all_present_str_array.include? resource_name
        
        dscl_vector = get_exec_preamble("-read", resource_name)
        begin
            dscl_output = execute(dscl_vector)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not get report.  command execution failed."
        end
        
        # JJM: We need a new hash to return back to our caller.
        attribute_hash = Hash.new
        
        # JJM: First, the output string goes into an array.
        #      Then, the each array element is split
        #      If you want to figure out what this is doing, I suggest
        #      ruby-debug, and stepping through it.
        dscl_output.split("\n").each do |line|
            # JJM: Split the attribute name and the list of values.
            ds_attribute, ds_values_string = line.split(':')

            # Split sets the values to nil if there's nothing after the :
            ds_values_string ||= ""
            
            # JJM: skip this attribute line if the Puppet::Type doesn't care about it.
            next unless (@@ds_to_ns_attribute_map.keys.include?(ds_attribute) and type_properties.include? @@ds_to_ns_attribute_map[ds_attribute])

            # JJM: We asked dscl to output url encoded values so we're able
            #     to machine parse on whitespace.  We need to urldecode:
            #     " Jeff%20McCune John%20Doe " => ["Jeff McCune", "John Doe"]
            ds_value_array = ds_values_string.scan(/[^\s]+/).collect do |v|
                url_decoded_value = CGI::unescape v
                if url_decoded_value =~ /^[-0-9]+$/
                    url_decoded_value.to_i
                else                
                    url_decoded_value
                end
            end
            
            # JJM: Finally, we're able to build up our attribute hash.
            #    Remember, the hash is keyed by NameService attribute names,
            #    not DirectoryService attribute names.
            # NOTE: We're also sort of cheating here...  DirectoryService
            #   is robust enough to allow multiple values for almost every
            #   attribute in the system.  Traditional NameService things
            #   really don't handle this case, so we'll always pull thet first
            #   value returned from DirectoryService.
            #   THERE MAY BE AN ORDERING ISSUE HERE, but I think it's ok...
            attribute_hash[@@ds_to_ns_attribute_map[ds_attribute]] = ds_value_array[0]
        end
        return attribute_hash
    end
    
    def self.get_exec_preamble(ds_action, resource_name = nil)
        # JJM 2007-07-24
        #     DSCL commands are often repetitive and contain the same positional
        #     arguments over and over. See http://developer.apple.com/documentation/Porting/Conceptual/PortingUnix/additionalfeatures/chapter_10_section_9.html
        #     for an example of what I mean.
        #     This method spits out proper DSCL commands for us.
        #     We EXPECT name to be @resource[:name] when called from an instance object.

        # There are two ways to specify paths in 10.5.  See man dscl.
        command_vector = [ command(:dscl), "-url", "." ]
        # JJM: The actual action to perform.  See "man dscl"
        #      Common actiosn: -create, -delete, -merge, -append, -passwd
        command_vector << ds_action
        # JJM: get_ds_path will spit back "Users" or "Groups",
        # etc...  Depending on the Puppet::Type of our self.
        if resource_name
            command_vector << "/%s/%s" % [ get_ds_path, resource_name ]
        else
            command_vector << "/%s" % [ get_ds_path ]
        end
        # JJM:  This returns most of the preamble of the command.
        #       e.g. 'dscl / -create /Users/mccune'
        return command_vector
    end

    def ensure=(ensure_value)
        super
        # JJM: Modeled after nameservice/netinfo.rb, we need to
        #   loop over all valid properties for the type we're managing
        #   and call the method which sets that property value
        #   Like netinfo, dscl can't create everything at once, afaik.
        if ensure_value == :present
            @resource.class.validproperties.each do |name|
                next if name == :ensure

                # LAK: We use property.sync here rather than directly calling
                # the settor method because the properties might do some kind
                # of conversion.  In particular, the user gid property might
                # have a string and need to convert it to a number
                if @resource.should(name)
                    @resource.property(name).sync
                elsif value = autogen(name)
                    self.send(name.to_s + "=", value)
                else
                    next
                end
            end
        end 
    end
    
    def password=(passphrase)
        # JJM: Setting the password is a special case.  We don't just
        #      set the attribute because we need to update the password
        #      databases.
        # FIRST, make sure the AuthenticationAuthority is ;ShadowHash;  If
        #  we don't do this, we don't get a shadow hash account.  ("Obviously...")
        dscl_vector = self.class.get_exec_preamble("-create", @resource[:name])
        dscl_vector << "AuthenticationAuthority" << ";ShadowHash;"
        begin
            dscl_output = execute(dscl_vector)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not set AuthenticationAuthority."
        end        
        
        # JJM: Second, we need to actually set the password.  dscl does
        #   some magic, creating the proper hash for us based on the
        #   AuthenticationAuthority attribute, set above.
        dscl_vector = self.class.get_exec_preamble("-passwd", @resource[:name])
        dscl_vector << passphrase
        # JJM: Should we not log the password string?  This may be a security
        #      risk...
        begin
            dscl_output = execute(dscl_vector)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not set password using command vector: %{dscl_vector.inspect}"
        end
    end
    
    # JJM: nameservice.rb defines methods for each attribute of the type.
    #   We implement these methods here, by implementing get() and set()
    #   See the resource_type= method defined in nameservice.rb
    #   I'm not sure what the implications are of doing things this way.
    #   It was a bit difficult to sort out what was happening in my head,
    #   but ruby-debug makes this process much more transparent.
    #
    def set(property, value)
        # JJM: As it turns out, the set method defined in our parent class
        #   is fine.  It just calls the modifycmd() method, which
        #   I'll implement here.
        super
    end
    
    def get(param)
        hash = getinfo(false)
        if hash
            return hash[param]
        else
            return :absent
        end
    end
    
    def modifycmd(property, value)
        # JJM: This method will assemble a exec vector which modifies
        #    a single property and it's value using dscl.
        # JJM: With /usr/bin/dscl, the -create option will destroy an
        #      existing property record if it exists
        exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
        # JJM: The following line just maps the NS name to the DS name
        #      e.g. { :uid => 'UniqueID' }
        exec_arg_vector << @@ns_to_ds_attribute_map[symbolize(property)]
        # JJM: The following line sends the actual value to set the property to
        exec_arg_vector << value.to_s
        return exec_arg_vector
    end
    
    def addcmd
        # JJM 2007-07-24: 
        #    - addcmd returns an array to be executed to create a new object.
        #    - This method is probably being called from the
        #      ensure= method in nameservice.rb, or here...
        #    - This should only be called if the object doesn't exist.
        # JJM: Blame nameservice.rb for the terse method name. =)
        #
        self.class.get_exec_preamble("-create", @resource[:name])
    end
    
    def deletecmd
        # JJM: Like addcmd, only called when deleting the object itself
        #    Note, this isn't used to delete properties of the object,
        #    at least that's how I understand it...
        self.class.get_exec_preamble("-delete", @resource[:name])
    end
    
    def getinfo(refresh = false)
        # JJM 2007-07-24: 
        #      Override the getinfo method, which is also defined in nameservice.rb
        #      This method returns and sets @infohash, which looks like:
        #      (NetInfo provider, user type...)
        #       @infohash = {:comment=>"Jeff McCune", :home=>"/Users/mccune", 
        #       :shell=>"/bin/zsh", :password=>"********", :uid=>502, :gid=>502,
        #       :name=>"mccune"}
        #
        # I'm not re-factoring the name "getinfo" because this method will be
        # most likely called by nameservice.rb, which I didn't write.
        if refresh or (! defined?(@property_value_cache_hash) or ! @property_value_cache_hash)
            # JJM 2007-07-24: OK, there's a bit of magic that's about to
            # happen... Let's see how strong my grip has become... =)
            # 
            # self is a provider instance of some Puppet::Type, like
            # Puppet::Type::User::ProviderDirectoryservice for the case of the
            # user type and this provider.
            # 
            # self.class looks like "user provider directoryservice", if that
            # helps you ...
            # 
            # self.class.resource_type is a reference to the Puppet::Type class,
            # probably Puppet::Type::User or Puppet::Type::Group, etc...
            # 
            # self.class.resource_type.validproperties is a class method,
            # returning an Array of the valid properties of that specific
            # Puppet::Type.
            # 
            # So... something like [:comment, :home, :password, :shell, :uid,
            # :groups, :ensure, :gid]
            # 
            # Ultimately, we add :name to the list, delete :ensure from the
            # list, then report on the remaining list. Pretty whacky, ehh?
            type_properties = [:name] + self.class.resource_type.validproperties
            type_properties.delete(:ensure) if type_properties.include? :ensure
            @property_value_cache_hash = self.class.single_report(@resource[:name], *type_properties)
        end
        return @property_value_cache_hash
    end
end
end
