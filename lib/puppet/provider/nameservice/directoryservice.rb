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
require 'facter/util/plist'
require 'cgi'


class Puppet::Provider::NameService
class DirectoryService < Puppet::Provider::NameService
    # JJM: Dive into the eigenclass
    class << self
        # JJM: This allows us to pass information when calling
        #      Puppet::Type.type
        #  e.g. Puppet::Type.type(:user).provide :directoryservice, :ds_path => "Users"
        #  This is referenced in the get_ds_path class method
        attr_writer :ds_path
        attr_writer :macosx_version_major
    end

    initvars()

    commands :dscl => "/usr/bin/dscl"
    commands :dseditgroup => "/usr/sbin/dseditgroup"
    commands :sw_vers => "/usr/bin/sw_vers"
    confine :operatingsystem => :darwin
    defaultfor :operatingsystem => :darwin


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
        'GeneratedUID' => :guid,
        'IPAddress'    => :ip_address,
        'ENetAddress'  => :en_address,
        'GroupMembership' => :members,
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
        :guid => 'GeneratedUID',
        :en_address => 'ENetAddress',
        :ip_address => 'IPAddress',
        :members => 'GroupMembership',
    }

    @@password_hash_dir = "/var/db/shadow/hash"

    def self.instances
        # JJM Class method that provides an array of instance objects of this
        #     type.
        # JJM: Properties are dependent on the Puppet::Type we're managine.
        type_property_array = [:name] + @resource_type.validproperties

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
        end
        # JJM: "Users" or "Groups" etc ...  (Based on the Puppet::Type)
        #       Remember this is a class method, so self.class is Class
        #       Also, @resource_type seems to be the reference to the
        #       Puppet::Type this class object is providing for.
        return @resource_type.name.to_s.capitalize + "s"
    end

    def self.get_macosx_version_major
        if defined? @macosx_version_major
            return @macosx_version_major
        end
        begin
            # Make sure we've loaded all of the facts
            Facter.loadfacts

            if Facter.value(:macosx_productversion_major)
                product_version_major = Facter.value(:macosx_productversion_major)
            else
                # TODO: remove this code chunk once we require Facter 1.5.5 or higher.
                Puppet.warning("DEPRECATION WARNING: Future versions of the directoryservice provider will require Facter 1.5.5 or newer.")            
                product_version = Facter.value(:macosx_productversion)
                if product_version.nil?
                    fail("Could not determine OS X version from Facter")
                end
                product_version_major = product_version.scan(/(\d+)\.(\d+)./).join(".")
            end
            if %w{10.0 10.1 10.2 10.3}.include?(product_version_major)
                fail("%s is not supported by the directoryservice provider" % product_version_major)
            end
            @macosx_version_major = product_version_major
            return @macosx_version_major
        rescue Puppet::ExecutionFailure => detail
            fail("Could not determine OS X version: %s" % detail)
        end
    end


    def self.list_all_present
        # JJM: List all objects of this Puppet::Type already present on the system.
        begin
            dscl_output = execute(get_exec_preamble("-list"))
        rescue Puppet::ExecutionFailure => detail
           fail("Could not get %s list from DirectoryService" % [ @resource_type.name.to_s ])
        end
        return dscl_output.split("\n")
    end

    def self.parse_dscl_url_data(dscl_output)
        # we need to construct a Hash from the dscl -url output to match
        # that returned by the dscl -plist output for 10.5+ clients.
        #
        # Nasty assumptions:
        #   a) no values *end* in a colon ':', only keys
        #   b) if a line ends in a colon and the next line does start with
        #      a space, then the second line is a value of the first.
        #   c) (implied by (b)) keys don't start with spaces.

        dscl_plist = {}
        dscl_output.split("\n").inject([]) do |array, line|
          if line =~ /^\s+/   # it's a value
            array[-1] << line # add the value to the previous key
          else
            array << line
          end
          array
        end.compact

        dscl_output.each do |line|
            # This should be a 'normal' entry. key and value on one line.
            # We split on ': ' to deal with keys/values with a colon in them.
            split_array = line.split(/:\s+/)
            key = split_array.first
            value = CGI::unescape(split_array.last.strip.chomp)
            # We need to treat GroupMembership separately as it is currently
            # the only attribute we care about multiple values for, and
            # the values can never contain spaces (shortnames)
            # We also make every value an array to be consistent with the
            # output of dscl -plist under 10.5
            if key == "GroupMembership"
                dscl_plist[key] = value.split(/\s/)
            else
                dscl_plist[key] = [value]
            end
        end
        return dscl_plist
    end

    def self.parse_dscl_plist_data(dscl_output)
        return Plist.parse_xml(dscl_output)
    end

    def self.generate_attribute_hash(input_hash, *type_properties)
        attribute_hash = {}
        input_hash.keys().each do |key|
            ds_attribute = key.sub("dsAttrTypeStandard:", "")
            next unless (@@ds_to_ns_attribute_map.keys.include?(ds_attribute) and type_properties.include? @@ds_to_ns_attribute_map[ds_attribute])
            ds_value = input_hash[key]
            case @@ds_to_ns_attribute_map[ds_attribute]
                when :members
                    ds_value = ds_value # only members uses arrays so far
                when :gid, :uid
                    # OS X stores objects like uid/gid as strings.
                    # Try casting to an integer for these cases to be
                    # consistent with the other providers and the group type
                    # validation
                    begin
                        ds_value = Integer(ds_value[0])
                    rescue ArgumentError
                        ds_value = ds_value[0]
                    end
                else ds_value = ds_value[0]
            end
            attribute_hash[@@ds_to_ns_attribute_map[ds_attribute]] = ds_value
        end

        # NBK: need to read the existing password here as it's not actually
        # stored in the user record. It is stored at a path that involves the
        # UUID of the user record for non-Mobile local acccounts.
        # Mobile Accounts are out of scope for this provider for now
        if @resource_type.validproperties.include?(:password)
            attribute_hash[:password] = self.get_password(attribute_hash[:guid])
        end
        return attribute_hash
    end

    def self.single_report(resource_name, *type_properties)
        # JJM 2007-07-24:
        #     Given a the name of an object and a list of properties of that
        #     object, return all property values in a hash.
        #
        #     This class method returns nil if the object doesn't exist
        #     Otherwise, it returns a hash of the object properties.

        all_present_str_array = list_all_present()

        # NBK: shortcut the process if the resource is missing
        return nil unless all_present_str_array.include? resource_name

        dscl_vector = get_exec_preamble("-read", resource_name)
        begin
            dscl_output = execute(dscl_vector)
        rescue Puppet::ExecutionFailure => detail
            fail("Could not get report.  command execution failed.")
        end

        # Two code paths is ugly, but until we can drop 10.4 support we don't
        # have a lot of choice. Ultimately this should all be done using Ruby
        # to access the DirectoryService APIs directly, but that's simply not
        # feasible for a while yet.
        case self.get_macosx_version_major
        when "10.4"
            dscl_plist = self.parse_dscl_url_data(dscl_output)
        when "10.5", "10.6"
            dscl_plist = self.parse_dscl_plist_data(dscl_output)
        end

        return self.generate_attribute_hash(dscl_plist, *type_properties)
    end

    def self.get_exec_preamble(ds_action, resource_name = nil)
        # JJM 2007-07-24
        #     DSCL commands are often repetitive and contain the same positional
        #     arguments over and over. See http://developer.apple.com/documentation/Porting/Conceptual/PortingUnix/additionalfeatures/chapter_10_section_9.html
        #     for an example of what I mean.
        #     This method spits out proper DSCL commands for us.
        #     We EXPECT name to be @resource[:name] when called from an instance object.

        # 10.4 doesn't support the -plist option for dscl, and 10.5 has a
        # different format for the -url output with objects with spaces in
        # their values. *sigh*. Use -url for 10.4 in the hope this can be
        # deprecated one day, and use -plist for 10.5 and higher.
        case self.get_macosx_version_major
        when "10.4"
            command_vector = [ command(:dscl), "-url", "." ]
        when "10.5", "10.6"
            command_vector = [ command(:dscl), "-plist", "." ]
        end
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

    def self.set_password(resource_name, guid, password_hash)
        password_hash_file = "#{@@password_hash_dir}/#{guid}"
        begin
            File.open(password_hash_file, 'w') { |f| f.write(password_hash)}
        rescue Errno::EACCES => detail
            fail("Could not write to password hash file: #{detail}")
        end

        # NBK: For shadow hashes, the user AuthenticationAuthority must contain a value of
        # ";ShadowHash;". The LKDC in 10.5 makes this more interesting though as it
        # will dynamically generate ;Kerberosv5;;username@LKDC:SHA1 attributes if
        # missing. Thus we make sure we only set ;ShadowHash; if it is missing, and
        # we can do this with the merge command. This allows people to continue to
        # use other custom AuthenticationAuthority attributes without stomping on them.
        #
        # There is a potential problem here in that we're only doing this when setting
        # the password, and the attribute could get modified at other times while the
        # hash doesn't change and so this doesn't get called at all... but
        # without switching all the other attributes to merge instead of create I can't
        # see a simple enough solution for this that doesn't modify the user record
        # every single time. This should be a rather rare edge case. (famous last words)

        dscl_vector = self.get_exec_preamble("-merge", resource_name)
        dscl_vector << "AuthenticationAuthority" << ";ShadowHash;"
        begin
            dscl_output = execute(dscl_vector)
        rescue Puppet::ExecutionFailure => detail
            fail("Could not set AuthenticationAuthority.")
        end
    end

    def self.get_password(guid)
        password_hash = nil
        password_hash_file = "#{@@password_hash_dir}/#{guid}"
        if File.exists?(password_hash_file) and File.file?(password_hash_file)
            if not File.readable?(password_hash_file)
                fail("Could not read password hash file at #{password_hash_file} for #{@resource[:name]}")
            end
            f = File.new(password_hash_file)
            password_hash = f.read
            f.close
        end
        password_hash
    end

    def ensure=(ensure_value)
        super
        # We need to loop over all valid properties for the type we're
        # managing and call the method which sets that property value
        # dscl can't create everything at once unfortunately.
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
      exec_arg_vector = self.class.get_exec_preamble("-read", @resource.name)
      exec_arg_vector << @@ns_to_ds_attribute_map[:guid]
      begin
          guid_output = execute(exec_arg_vector)
          guid_plist = Plist.parse_xml(guid_output)
          # Although GeneratedUID like all DirectoryService values can be multi-valued
          # according to the schema, in practice user accounts cannot have multiple UUIDs
          # otherwise Bad Things Happen, so we just deal with the first value.
          guid = guid_plist["dsAttrTypeStandard:#{@@ns_to_ds_attribute_map[:guid]}"][0]
          self.class.set_password(@resource.name, guid, passphrase)
      rescue Puppet::ExecutionFailure => detail
          fail("Could not set %s on %s[%s]: %s" % [param, @resource.class.name, @resource.name, detail])
      end
    end

    # NBK: we override @parent.set as we need to execute a series of commands
    # to deal with array values, rather than the single command nameservice.rb
    # expects to be returned by modifycmd. Thus we don't bother defining modifycmd.

    def set(param, value)
        self.class.validate(param, value)
        current_members = @property_value_cache_hash[:members]
        if param == :members
            # If we are meant to be authoritative for the group membership
            # then remove all existing members who haven't been specified
            # in the manifest.
            if @resource[:auth_membership] and not current_members.nil?
                remove_unwanted_members(current_members, value)
             end

             # if they're not a member, make them one.
             add_members(current_members, value)
        else
            exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
            # JJM: The following line just maps the NS name to the DS name
            #      e.g. { :uid => 'UniqueID' }
            exec_arg_vector << @@ns_to_ds_attribute_map[symbolize(param)]
            # JJM: The following line sends the actual value to set the property to
            exec_arg_vector << value.to_s
            begin
                execute(exec_arg_vector)
            rescue Puppet::ExecutionFailure => detail
                fail("Could not set %s on %s[%s]: %s" % [param, @resource.class.name, @resource.name, detail])
            end
        end
    end

    # NBK: we override @parent.create as we need to execute a series of commands
    # to create objects with dscl, rather than the single command nameservice.rb
    # expects to be returned by addcmd. Thus we don't bother defining addcmd.
    def create
        if exists?
            info "already exists"
            return nil
        end

        # NBK: First we create the object with a known guid so we can set the contents
        # of the password hash if required
        # Shelling out sucks, but for a single use case it doesn't seem worth
        # requiring people install a UUID library that doesn't come with the system.
        # This should be revisited if Puppet starts managing UUIDs for other platform
        # user records.
        guid = %x{/usr/bin/uuidgen}.chomp

        exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
        exec_arg_vector << @@ns_to_ds_attribute_map[:guid] << guid
        begin
          execute(exec_arg_vector)
        rescue Puppet::ExecutionFailure => detail
            fail("Could not set GeneratedUID for %s %s: %s" %
                [@resource.class.name, @resource.name, detail])
        end

        if value = @resource.should(:password) and value != ""
          self.class.set_password(@resource[:name], guid, value)
        end

        # Now we create all the standard properties
        Puppet::Type.type(@resource.class.name).validproperties.each do |property|
            next if property == :ensure
            if value = @resource.should(property) and value != ""
                if property == :members
                    add_members(nil, value)
                else
                    exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
                    exec_arg_vector << @@ns_to_ds_attribute_map[symbolize(property)]
                    next if property == :password  # skip setting the password here
                    exec_arg_vector << value.to_s
                    begin
                      execute(exec_arg_vector)
                    rescue Puppet::ExecutionFailure => detail
                        fail("Could not create %s %s: %s" %
                            [@resource.class.name, @resource.name, detail])
                    end
                end
            end
        end
    end

    def remove_unwanted_members(current_members, new_members)
        current_members.each do |member|
            if not new_members.include?(member)
                cmd = [:dseditgroup, "-o", "edit", "-n", ".", "-d", member, @resource[:name]]
                begin
                     execute(cmd)
                rescue Puppet::ExecutionFailure => detail
                     fail("Could not remove %s from group: %s, %s" % [member, @resource.name, detail])
                end
             end
         end
    end

    def add_members(current_members, new_members)
        new_members.each do |new_member|
           if current_members.nil? or not current_members.include?(new_member)
               cmd = [:dseditgroup, "-o", "edit", "-n", ".", "-a", new_member, @resource[:name]]
               begin
                    execute(cmd)
               rescue Puppet::ExecutionFailure => detail
                    fail("Could not add %s to group: %s, %s" % [new_member, @resource.name, detail])
               end
           end
        end
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
        #      This method returns and sets @infohash
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
            type_properties << :guid  # append GeneratedUID so we just get the report here
            @property_value_cache_hash = self.class.single_report(@resource[:name], *type_properties)
            [:uid, :gid].each do |param|
                @property_value_cache_hash[param] = @property_value_cache_hash[param].to_i if @property_value_cache_hash and @property_value_cache_hash.include?(param)
            end
        end
        return @property_value_cache_hash
    end
end
end
