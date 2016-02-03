require 'puppet'
require 'puppet/provider/nameservice'
require 'puppet/util/plist' if Puppet.features.cfpropertylist?
require 'fileutils'

class Puppet::Provider::NameService::DirectoryService < Puppet::Provider::NameService
  # JJM: Dive into the singleton_class
  class << self
    # JJM: This allows us to pass information when calling
    #      Puppet::Type.type
    #  e.g. Puppet::Type.type(:user).provide :directoryservice, :ds_path => "Users"
    #  This is referenced in the get_ds_path class method
    attr_writer :ds_path
  end

  initvars

  commands :dscl => "/usr/bin/dscl"
  commands :dseditgroup => "/usr/sbin/dseditgroup"
  commands :sw_vers => "/usr/bin/sw_vers"
  confine :operatingsystem => :darwin
  confine :feature         => :cfpropertylist
  defaultfor :operatingsystem => :darwin


  # JJM 2007-07-25: This map is used to map NameService attributes to their
  #     corresponding DirectoryService attribute names.
  #     See: http://images.apple.com/server/docs.Open_Directory_v10.4.pdf
  # JJM: Note, this is de-coupled from the Puppet::Type, and must
  #     be actively maintained.  There may also be collisions with different
  #     types (Users, Groups, Mounts, Hosts, etc...)
  def ds_to_ns_attribute_map; self.class.ds_to_ns_attribute_map; end
  def self.ds_to_ns_attribute_map
    {
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
  end

  # JJM The same table as above, inverted.
  def ns_to_ds_attribute_map; self.class.ns_to_ds_attribute_map end
  def self.ns_to_ds_attribute_map
    @ns_to_ds_attribute_map ||= ds_to_ns_attribute_map.invert
  end

  def self.password_hash_dir
    '/var/db/shadow/hash'
  end

  def self.users_plist_dir
    '/var/db/dslocal/nodes/Default/users'
  end

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
    return @ds_path if defined?(@ds_path)
    # JJM: "Users" or "Groups" etc ...  (Based on the Puppet::Type)
    #       Remember this is a class method, so self.class is Class
    #       Also, @resource_type seems to be the reference to the
    #       Puppet::Type this class object is providing for.
    @resource_type.name.to_s.capitalize + "s"
  end

  def self.list_all_present
    # JJM: List all objects of this Puppet::Type already present on the system.
    begin
      dscl_output = execute(get_exec_preamble("-list"))
    rescue Puppet::ExecutionFailure
      fail("Could not get #{@resource_type.name} list from DirectoryService")
    end
    dscl_output.split("\n")
  end

  def self.parse_dscl_plist_data(dscl_output)
    Puppet::Util::Plist.parse_plist(dscl_output)
  end

  def self.generate_attribute_hash(input_hash, *type_properties)
    attribute_hash = {}
    input_hash.keys.each do |key|
      ds_attribute = key.sub("dsAttrTypeStandard:", "")
      next unless (ds_to_ns_attribute_map.keys.include?(ds_attribute) and type_properties.include? ds_to_ns_attribute_map[ds_attribute])
      ds_value = input_hash[key]
      case ds_to_ns_attribute_map[ds_attribute]
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
      attribute_hash[ds_to_ns_attribute_map[ds_attribute]] = ds_value
    end

    # NBK: need to read the existing password here as it's not actually
    # stored in the user record. It is stored at a path that involves the
    # UUID of the user record for non-Mobile local acccounts.
    # Mobile Accounts are out of scope for this provider for now
    attribute_hash[:password] = self.get_password(attribute_hash[:guid], attribute_hash[:name]) if @resource_type.validproperties.include?(:password) and Puppet.features.root?
    attribute_hash
  end

  def self.single_report(resource_name, *type_properties)
    # JJM 2007-07-24:
    #     Given a the name of an object and a list of properties of that
    #     object, return all property values in a hash.
    #
    #     This class method returns nil if the object doesn't exist
    #     Otherwise, it returns a hash of the object properties.

    all_present_str_array = list_all_present

    # NBK: shortcut the process if the resource is missing
    return nil unless all_present_str_array.include? resource_name

    dscl_vector = get_exec_preamble("-read", resource_name)
    begin
      dscl_output = execute(dscl_vector)
    rescue Puppet::ExecutionFailure
      fail("Could not get report.  command execution failed.")
    end

    dscl_plist = self.parse_dscl_plist_data(dscl_output)

    self.generate_attribute_hash(dscl_plist, *type_properties)
  end

  def self.get_exec_preamble(ds_action, resource_name = nil)
    # JJM 2007-07-24
    #     DSCL commands are often repetitive and contain the same positional
    #     arguments over and over. See https://developer.apple.com/documentation/Porting/Conceptual/PortingUnix/additionalfeatures/chapter_10_section_9.html
    #     for an example of what I mean.
    #     This method spits out proper DSCL commands for us.
    #     We EXPECT name to be @resource[:name] when called from an instance object.

    command_vector = [ command(:dscl), "-plist", "." ]

    # JJM: The actual action to perform.  See "man dscl"
    #      Common actiosn: -create, -delete, -merge, -append, -passwd
    command_vector << ds_action
    # JJM: get_ds_path will spit back "Users" or "Groups",
    # etc...  Depending on the Puppet::Type of our self.
    if resource_name
      command_vector << "/#{get_ds_path}/#{resource_name}"
    else
      command_vector << "/#{get_ds_path}"
    end
    # JJM:  This returns most of the preamble of the command.
    #       e.g. 'dscl / -create /Users/mccune'
    command_vector
  end

  def self.set_password(resource_name, guid, password_hash)
    # 10.7 uses salted SHA512 password hashes which are 128 characters plus
    # an 8 character salt. Previous versions used a SHA1 hash padded with
    # zeroes. If someone attempts to use a password hash that worked with
    # a previous version of OX X, we will fail early and warn them.
    if password_hash.length != 136
      fail("OS X 10.7 requires a Salted SHA512 hash password of 136 characters. \
           Please check your password and try again.")
    end

    plist_file = "#{users_plist_dir}/#{resource_name}.plist"
    if Puppet::FileSystem.exist?(plist_file)
      # If a plist already exists in /var/db/dslocal/nodes/Default/users, then
      # we will need to extract the binary plist from the 'ShadowHashData'
      # key, log the new password into the resultant plist's 'SALTED-SHA512'
      # key, and then save the entire structure back.
      users_plist = Puppet::Util::Plist.read_plist_file(plist_file)

      # users_plist['ShadowHashData'][0] is actually a binary plist
      # that's nested INSIDE the user's plist (which itself is a binary
      # plist). If we encounter a user plist that DOESN'T have a
      # ShadowHashData field, create one.
      if users_plist['ShadowHashData']
        password_hash_plist = users_plist['ShadowHashData'][0]
        converted_hash_plist = convert_binary_to_hash(password_hash_plist)
      else
        users_plist['ShadowHashData'] = ''
        converted_hash_plist = {'SALTED-SHA512' => ''}
      end

      # converted_hash_plist['SALTED-SHA512'] expects a Base64 encoded
      # string. The password_hash provided as a resource attribute is a
      # hex value. We need to convert the provided hex value to a Base64
      # encoded string to nest it in the converted hash plist.
      converted_hash_plist['SALTED-SHA512'] = \
        password_hash.unpack('a2'*(password_hash.size/2)).collect { |i| i.hex.chr }.join

      # Finally, we can convert the nested plist back to binary, embed it
      # into the user's plist, and convert the resultant plist back to
      # a binary plist.
      changed_plist = convert_hash_to_binary(converted_hash_plist)
      users_plist['ShadowHashData'][0] = changed_plist
      Puppet::Util::Plist.write_plist_file(users_plist, plist_file, :binary)
    end
  end

  def self.get_password(guid, username)
    plist_file = "#{users_plist_dir}/#{username}.plist"
    if Puppet::FileSystem.exist?(plist_file)
      # If a plist exists in /var/db/dslocal/nodes/Default/users, we will
      # extract the binary plist from the 'ShadowHashData' key, decode the
      # salted-SHA512 password hash, and then return it.
      users_plist = Puppet::Util::Plist.read_plist_file(plist_file)

      if users_plist['ShadowHashData']
        # users_plist['ShadowHashData'][0] is actually a binary plist
        # that's nested INSIDE the user's plist (which itself is a binary
        # plist).
        password_hash_plist = users_plist['ShadowHashData'][0]
        converted_hash_plist = convert_binary_to_hash(password_hash_plist)

        # converted_hash_plist['SALTED-SHA512'] is a Base64 encoded
        # string. The password_hash provided as a resource attribute is a
        # hex value. We need to convert the Base64 encoded string to a
        # hex value and provide it back to Puppet.
        password_hash = converted_hash_plist['SALTED-SHA512'].unpack("H*")[0]
        password_hash
      end
    end
  end

  # This method will accept a hash and convert it to a binary plist (string value).
  def self.convert_hash_to_binary(plist_data)
    Puppet.debug('Converting plist hash to binary')
    Puppet::Util::Plist.dump_plist(plist_data, :binary)
  end

  # This method will accept a binary plist (as a string) and convert it to a hash.
  def self.convert_binary_to_hash(plist_data)
    Puppet.debug('Converting binary plist to hash')
    Puppet::Util::Plist.parse_plist(plist_data)
  end

  # Unlike most other *nixes, OS X doesn't provide built in functionality
  # for automatically assigning uids and gids to accounts, so we set up these
  # methods for consumption by functionality like --mkusers
  # By default we restrict to a reasonably sane range for system accounts
  def self.next_system_id(id_type, min_id=20)
    dscl_args = ['.', '-list']
    if id_type == 'uid'
      dscl_args << '/Users' << 'uid'
    elsif id_type == 'gid'
      dscl_args << '/Groups' << 'gid'
    else
      fail("Invalid id_type #{id_type}. Only 'uid' and 'gid' supported")
    end
    dscl_out = dscl(dscl_args)
    # We're ok with throwing away negative uids here.
    ids = dscl_out.split.compact.collect { |l| l.to_i if l.match(/^\d+$/) }
    ids.compact!.sort! { |a,b| a.to_f <=> b.to_f }
    # We're just looking for an unused id in our sorted array.
    ids.each_index do |i|
      next_id = ids[i] + 1
      return next_id if ids[i+1] != next_id and next_id >= min_id
    end
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
    exec_arg_vector << ns_to_ds_attribute_map[:guid]
    begin
      guid_output = execute(exec_arg_vector)
      guid_plist = Puppet::Util::Plist.parse_plist(guid_output)
      # Although GeneratedUID like all DirectoryService values can be multi-valued
      # according to the schema, in practice user accounts cannot have multiple UUIDs
      # otherwise Bad Things Happen, so we just deal with the first value.
      guid = guid_plist["dsAttrTypeStandard:#{ns_to_ds_attribute_map[:guid]}"][0]
      self.class.set_password(@resource.name, guid, passphrase)
    rescue Puppet::ExecutionFailure => detail
      fail("Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}")
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
      remove_unwanted_members(current_members, value) if @resource[:auth_membership] and not current_members.nil?

      # if they're not a member, make them one.
      add_members(current_members, value)
    else
      exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
      # JJM: The following line just maps the NS name to the DS name
      #      e.g. { :uid => 'UniqueID' }
      exec_arg_vector << ns_to_ds_attribute_map[param.intern]
      # JJM: The following line sends the actual value to set the property to
      exec_arg_vector << value.to_s
      begin
        execute(exec_arg_vector)
      rescue Puppet::ExecutionFailure => detail
        fail("Could not set #{param} on #{@resource.class.name}[#{@resource.name}]: #{detail}")
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
    exec_arg_vector << ns_to_ds_attribute_map[:guid] << guid
    begin
      execute(exec_arg_vector)
    rescue Puppet::ExecutionFailure => detail
      fail("Could not set GeneratedUID for #{@resource.class.name} #{@resource.name}: #{detail}")
    end

    if value = @resource.should(:password) and value != ""
      self.class.set_password(@resource[:name], guid, value)
    end

    # Now we create all the standard properties
    Puppet::Type.type(@resource.class.name).validproperties.each do |property|
      next if property == :ensure
      value = @resource.should(property)
      if property == :gid and value.nil?
        value = self.class.next_system_id(id_type='gid')
      end
      if property == :uid and value.nil?
        value = self.class.next_system_id(id_type='uid')
      end
      if value != "" and not value.nil?
        if property == :members
          add_members(nil, value)
        else
          exec_arg_vector = self.class.get_exec_preamble("-create", @resource[:name])
          exec_arg_vector << ns_to_ds_attribute_map[property.intern]
          next if property == :password  # skip setting the password here
          exec_arg_vector << value.to_s
          begin
            execute(exec_arg_vector)
          rescue Puppet::ExecutionFailure => detail
            fail("Could not create #{@resource.class.name} #{@resource.name}: #{detail}")
          end
        end
      end
    end
  end

  def remove_unwanted_members(current_members, new_members)
    current_members.each do |member|
      if not new_members.flatten.include?(member)
        cmd = [:dseditgroup, "-o", "edit", "-n", ".", "-d", member, @resource[:name]]
        begin
          execute(cmd)
        rescue Puppet::ExecutionFailure => detail
          # TODO: We're falling back to removing the member using dscl due to rdar://8481241
          # This bug causes dseditgroup to fail to remove a member if that member doesn't exist
          cmd = [:dscl, ".", "-delete", "/Groups/#{@resource.name}", "GroupMembership", member]
          begin
            execute(cmd)
          rescue Puppet::ExecutionFailure => detail
            fail("Could not remove #{member} from group: #{@resource.name}, #{detail}")
          end
        end
      end
    end
  end

  def add_members(current_members, new_members)
    new_members.flatten.each do |new_member|
      if current_members.nil? or not current_members.include?(new_member)
        cmd = [:dseditgroup, "-o", "edit", "-n", ".", "-a", new_member, @resource[:name]]
        begin
          execute(cmd)
        rescue Puppet::ExecutionFailure => detail
          fail("Could not add #{new_member} to group: #{@resource.name}, #{detail}")
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
    @property_value_cache_hash
  end
end

