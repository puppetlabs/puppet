require 'puppet'
require 'puppet/util/plist' if Puppet.features.cfpropertylist?
require 'base64'

Puppet::Type.type(:user).provide :directoryservice do
  desc "User management on OS X."

##                   ##
## Provider Settings ##
##                   ##

  # Provider command declarations
  commands :uuidgen      => '/usr/bin/uuidgen'
  commands :dsimport     => '/usr/bin/dsimport'
  commands :dscl         => '/usr/bin/dscl'
  commands :dscacheutil  => '/usr/bin/dscacheutil'

  # Provider confines and defaults
  confine    :operatingsystem => :darwin
  confine    :feature         => :cfpropertylist
  defaultfor :operatingsystem => :darwin

  # Need this to create getter/setter methods automagically
  # This command creates methods that return @property_hash[:value]
  mk_resource_methods

  # JJM: OS X can manage passwords.
  has_feature :manages_passwords

  # 10.8 Passwords use a PBKDF2 salt value
  has_features :manages_password_salt

  #provider can set the user's shell
  has_feature :manages_shell

##               ##
## Class Methods ##
##               ##

  # This method exists to map the dscl values to the correct Puppet
  # properties. This stays relatively consistent, but who knows what
  # Apple will do next year...
  def self.ds_to_ns_attribute_map
    {
      'RecordName'       => :name,
      'PrimaryGroupID'   => :gid,
      'NFSHomeDirectory' => :home,
      'UserShell'        => :shell,
      'UniqueID'         => :uid,
      'RealName'         => :comment,
      'Password'         => :password,
      'GeneratedUID'     => :guid,
      'IPAddress'        => :ip_address,
      'ENetAddress'      => :en_address,
      'GroupMembership'  => :members,
    }
  end

  def self.ns_to_ds_attribute_map
    @ns_to_ds_attribute_map ||= ds_to_ns_attribute_map.invert
  end

  # Prefetching is necessary to use @property_hash inside any setter methods.
  # self.prefetch uses self.instances to gather an array of user instances
  # on the system, and then populates the @property_hash instance variable
  # with attribute data for the specific instance in question (i.e. it
  # gathers the 'is' values of the resource into the @property_hash instance
  # variable so you don't have to read from the system every time you need
  # to gather the 'is' values for a resource. The downside here is that
  # populating this instance variable for every resource on the system
  # takes time and front-loads your Puppet run.
  def self.prefetch(resources)
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  # This method assembles an array of provider instances containing
  # information about every instance of the user type on the system (i.e.
  # every user and its attributes). The `puppet resource` command relies
  # on self.instances to gather an array of user instances in order to
  # display its output.
  def self.instances
    get_all_users.collect do |user|
      self.new(generate_attribute_hash(user))
    end
  end

  # Return an array of hashes containing information about every user on
  # the system.
  def self.get_all_users
    Puppet::Util::Plist.parse_plist(dscl '-plist', '.', 'readall', '/Users')
  end

  # This method accepts an individual user plist, passed as a hash, and
  # strips the dsAttrTypeStandard: prefix that dscl adds for each key.
  # An attribute hash is assembled and returned from the properties
  # supported by the user type.
  def self.generate_attribute_hash(input_hash)
    attribute_hash = {}
    input_hash.keys.each do |key|
      ds_attribute = key.sub("dsAttrTypeStandard:", "")
      next unless ds_to_ns_attribute_map.keys.include?(ds_attribute)
      ds_value = input_hash[key]
      case ds_to_ns_attribute_map[ds_attribute]
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
    attribute_hash[:ensure]         = :present
    attribute_hash[:provider]       = :directoryservice
    attribute_hash[:shadowhashdata] = get_attribute_from_dscl('Users', attribute_hash[:name], 'ShadowHashData')

    ##############
    # Get Groups #
    ##############
    groups_array = []
    get_list_of_groups.each do |group|
      if group["dsAttrTypeStandard:GroupMembership"] and group["dsAttrTypeStandard:GroupMembership"].include?(attribute_hash[:name])
        groups_array << group["dsAttrTypeStandard:RecordName"][0]
      end

      if group["dsAttrTypeStandard:GroupMembers"] and group["dsAttrTypeStandard:GroupMembers"].include?(attribute_hash[:guid])
        groups_array << group["dsAttrTypeStandard:RecordName"][0]
      end
    end
    attribute_hash[:groups] = groups_array.uniq.sort.join(',')

    ################################
    # Get Password/Salt/Iterations #
    ################################
    if attribute_hash[:shadowhashdata].empty?
      attribute_hash[:password] = '*'
    else
      embedded_binary_plist = get_embedded_binary_plist(attribute_hash[:shadowhashdata])
      if embedded_binary_plist['SALTED-SHA512']
        attribute_hash[:password] = get_salted_sha512(embedded_binary_plist)
      else
        attribute_hash[:password]   = get_salted_sha512_pbkdf2('entropy', embedded_binary_plist)
        attribute_hash[:salt]       = get_salted_sha512_pbkdf2('salt', embedded_binary_plist)
        attribute_hash[:iterations] = get_salted_sha512_pbkdf2('iterations', embedded_binary_plist)
      end
    end

    attribute_hash
  end

  def self.get_os_version
    @os_version ||= Facter.value(:macosx_productversion_major)
  end

  # Use dscl to retrieve an array of hashes containing attributes about all
  # of the local groups on the machine.
  def self.get_list_of_groups
    @groups ||= Puppet::Util::Plist.parse_plist(dscl '-plist', '.', 'readall', '/Groups')
  end

  # Perform a dscl lookup at the path specified for the specific keyname
  # value. The value returned is the first item within the array returned
  # from dscl
  def self.get_attribute_from_dscl(path, username, keyname)
    Puppet::Util::Plist.parse_plist(dscl '-plist', '.', 'read', "/#{path}/#{username}", keyname)
  end

  # The plist embedded in the ShadowHashData key is a binary plist. The
  # plist library doesn't read binary plists, so we need to
  # extract the binary plist, convert it to XML, and return it.
  def self.get_embedded_binary_plist(shadow_hash_data)
    embedded_binary_plist = Array(shadow_hash_data['dsAttrTypeNative:ShadowHashData'][0].delete(' ')).pack('H*')
    convert_binary_to_hash(embedded_binary_plist)
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

  # The salted-SHA512 password hash in 10.7 is stored in the 'SALTED-SHA512'
  # key as binary data. That data is extracted and converted to a hex string.
  def self.get_salted_sha512(embedded_binary_plist)
    embedded_binary_plist['SALTED-SHA512'].unpack("H*")[0]
  end

  # This method reads the passed embedded_binary_plist hash and returns values
  # according to which field is passed.  Arguments passed are the hash
  # containing the value read from the 'ShadowHashData' key in the User's
  # plist, and the field to be read (one of 'entropy', 'salt', or 'iterations')
  def self.get_salted_sha512_pbkdf2(field, embedded_binary_plist)
    case field
    when 'salt', 'entropy'
      embedded_binary_plist['SALTED-SHA512-PBKDF2'][field].unpack('H*').first
    when 'iterations'
      Integer(embedded_binary_plist['SALTED-SHA512-PBKDF2'][field])
    else
      raise Puppet::Error, 'Puppet has tried to read an incorrect value from the ' +
           "SALTED-SHA512-PBKDF2 hash. Acceptable fields are 'salt', " +
           "'entropy', or 'iterations'."
    end
  end

  # In versions 10.5 and 10.6 of OS X, the password hash is stored in a file
  # in the /var/db/shadow/hash directory that matches the GUID of the user.
  def self.get_sha1(guid)
    password_hash = nil
    password_hash_file = "#{password_hash_dir}/#{guid}"
    if Puppet::FileSystem.exist?(password_hash_file) and File.file?(password_hash_file)
      raise Puppet::Error, "Could not read password hash file at #{password_hash_file}" if not File.readable?(password_hash_file)
      f = File.new(password_hash_file)
      password_hash = f.read
      f.close
    end
    password_hash
  end


##                   ##
## Ensurable Methods ##
##                   ##

  def exists?
    begin
      dscl '.', 'read', "/Users/#{@resource.name}"
    rescue Puppet::ExecutionFailure => e
      Puppet.debug("User was not found, dscl returned: #{e.inspect}")
      return false
    end
    true
  end

  # This method is called if ensure => present is passed and the exists?
  # method returns false. Dscl will directly set most values, but the
  # setter methods will be used for any exceptions.
  def create
    create_new_user(@resource.name)

    # Retrieve the user's GUID
    @guid = self.class.get_attribute_from_dscl('Users', @resource.name, 'GeneratedUID')['dsAttrTypeStandard:GeneratedUID'][0]

    # Get an array of valid User type properties
    valid_properties = Puppet::Type.type('User').validproperties

    # Iterate through valid User type properties
    valid_properties.each do |attribute|
      next if attribute == :ensure
      value = @resource.should(attribute)

      # Value defaults
      if value.nil?
        value = case attribute
                when :gid
                  '20'
                when :uid
                  next_system_id
                when :comment
                  @resource.name
                when :shell
                  '/bin/bash'
                when :home
                  "/Users/#{@resource.name}"
                else
                  nil
                end
      end

      # Ensure group names are converted to integers.
      value = Puppet::Util.gid(value) if attribute == :gid

      ## Set values ##
      # For the :password and :groups properties, call the setter methods
      # to enforce those values. For everything else, use dscl with the
      # ns_to_ds_attribute_map to set the appropriate values.
      if value != "" and not value.nil?
        case attribute
        when :password
          self.password = value
        when :iterations
          self.iterations = value
        when :salt
          self.salt = value
        when :groups
          value.split(',').each do |group|
            merge_attribute_with_dscl('Groups', group, 'GroupMembership', @resource.name)
            merge_attribute_with_dscl('Groups', group, 'GroupMembers', @guid)
          end
        else
          merge_attribute_with_dscl('Users', @resource.name, self.class.ns_to_ds_attribute_map[attribute], value)
        end
      end
    end
  end

  # This method is called when ensure => absent has been set.
  # Deleting a user is handled by dscl
  def delete
    dscl '.', '-delete', "/Users/#{@resource.name}"
  end

##                       ##
## Getter/Setter Methods ##
##                       ##

  # In the setter method we're only going to take action on groups for which
  # the user is not currently a member.
  def groups=(value)
    guid = self.class.get_attribute_from_dscl('Users', @resource.name, 'GeneratedUID')['dsAttrTypeStandard:GeneratedUID'][0]
    groups_to_add = value.split(',') - groups.split(',')
    groups_to_add.each do |group|
      merge_attribute_with_dscl('Groups', group, 'GroupMembership', @resource.name)
      merge_attribute_with_dscl('Groups', group, 'GroupMembers', guid)
    end
  end

  # If you thought GETTING a password was bad, try SETTING it. This method
  # makes me want to cry. A thousand tears...
  #
  # I've been unsuccessful in tracking down a way to set the password for
  # a user using dscl that DOESN'T require passing it as plaintext. We were
  # also unable to get dsimport to work like this. Due to these downfalls,
  # the sanest method requires opening the user's plist, dropping in the
  # password hash, and serializing it back to disk. The problems with THIS
  # method revolve around dscl. Any time you directly modify a user's plist,
  # you need to flush the cache that dscl maintains.
  def password=(value)
    if self.class.get_os_version == '10.7'
      if value.length != 136
        raise Puppet::Error, "OS X 10.7 requires a Salted SHA512 hash password of 136 characters.  Please check your password and try again."
      end
    else
      if value.length != 256
         raise Puppet::Error, "OS X versions > 10.7 require a Salted SHA512 PBKDF2 password hash of 256 characters. Please check your password and try again."
      end

      assert_full_pbkdf2_password
    end

    # Methods around setting the password on OS X are the ONLY methods that
    # cannot use dscl (because the only way to set it via dscl is by passing
    # a plaintext password - which is bad). Because of this, we have to change
    # the user's plist directly. DSCL has its own caching mechanism, which
    # means that every time we call dscl in this provider we're not directly
    # changing values on disk (instead, those calls are cached and written
    # to disk according to Apple's prioritization algorithms). When Puppet
    # needs to set the password property on OS X > 10.6, the provider has to
    # tell dscl to write its cache to disk before modifying the user's
    # plist. The 'dscacheutil -flushcache' command does this. Another issue
    # is how fast Puppet makes calls to dscl and how long it takes dscl to
    # enter those calls into its cache. We have to sleep for 2 seconds before
    # flushing the dscl cache to allow all dscl calls to get INTO the cache
    # first. This could be made faster (and avoid a sleep call) by finding
    # a way to enter calls into the dscl cache faster. A sleep time of 1
    # second would intermittantly require a second Puppet run to set
    # properties, so 2 seconds seems to be the minimum working value.
    sleep 2
    flush_dscl_cache
    write_password_to_users_plist(value)

    # Since we just modified the user's plist, we need to flush the ds cache
    # again so dscl can pick up on the changes we made.
    flush_dscl_cache
  end

  # The iterations and salt properties, like the password property, can only
  # be modified by directly changing the user's plist. Because of this fact,
  # we have to treat the ds cache just like you would in the password=
  # method.
  def iterations=(value)
    if (Puppet::Util::Package.versioncmp(self.class.get_os_version, '10.7') > 0)
      assert_full_pbkdf2_password

      sleep 2
      flush_dscl_cache
      users_plist = get_users_plist(@resource.name)
      shadow_hash_data = get_shadow_hash_data(users_plist)
      set_salted_pbkdf2(users_plist, shadow_hash_data, 'iterations', value)
      flush_dscl_cache
    end
  end

  # The iterations and salt properties, like the password property, can only
  # be modified by directly changing the user's plist. Because of this fact,
  # we have to treat the ds cache just like you would in the password=
  # method.
  def salt=(value)
    if (Puppet::Util::Package.versioncmp(self.class.get_os_version, '10.7') > 0)
      assert_full_pbkdf2_password

      sleep 2
      flush_dscl_cache
      users_plist = get_users_plist(@resource.name)
      shadow_hash_data = get_shadow_hash_data(users_plist)
      set_salted_pbkdf2(users_plist, shadow_hash_data, 'salt', value)
      flush_dscl_cache
    end
  end

  #####
  # Dynamically create setter methods for dscl properties
  #####
  #
  # Setter methods are only called when a resource currently has a value for
  # that property and it needs changed (true here since all of these values
  # have a default that is set in the create method). We don't want to merge
  # in additional values if an incorrect value is set, we want to CHANGE it.
  # When using the -change argument in dscl, the old value needs to be passed
  # first (followed by the new value). Because of this, we get the current
  # value from the @property_hash variable and then use the value passed as
  # the new value. Because we're prefetching instances of the provider, it's
  # possible that the value determined at the start of the run may be stale
  # (i.e. someone changed the value by hand during a Puppet run) - if that's
  # the case we rescue the error from dscl and alert the user.
  #
  # In the event that the user doesn't HAVE a value for the attribute, the
  # provider should use the -merge option with dscl to add the attribute value
  # for the user record
  ['home', 'uid', 'gid', 'comment', 'shell'].each do |setter_method|
    define_method("#{setter_method}=") do |value|
      if @property_hash[setter_method.intern]
        begin
          dscl '.', '-change', "/Users/#{resource.name}", self.class.ns_to_ds_attribute_map[setter_method.intern], @property_hash[setter_method.intern], value
        rescue Puppet::ExecutionFailure => e
          raise Puppet::Error, "Cannot set the #{setter_method} value of '#{value}' for user " +
               "#{@resource.name} due to the following error: #{e.inspect}", e.backtrace
        end
      else
        begin
          dscl '.', '-merge', "/Users/#{resource.name}", self.class.ns_to_ds_attribute_map[setter_method.intern], value
        rescue Puppet::ExecutionFailure => e
          raise Puppet::Error, "Cannot set the #{setter_method} value of '#{value}' for user " +
               "#{@resource.name} due to the following error: #{e.inspect}", e.backtrace
        end
      end
    end
  end


  ##                ##
  ## Helper Methods ##
  ##                ##

  def assert_full_pbkdf2_password
    missing = [:password, :salt, :iterations].select { |parameter| @resource[parameter].nil? }

    if !missing.empty?
       raise Puppet::Error, "OS X versions > 10\.7 use PBKDF2 password hashes, which requires all three of salt, iterations, and password hash. This resource is missing: #{missing.join(', ')}."
    end
  end

  def users_plist_dir
    '/var/db/dslocal/nodes/Default/users'
  end

  def self.password_hash_dir
    '/var/db/shadow/hash'
  end

  # This method will merge in a given value using dscl
  def merge_attribute_with_dscl(path, username, keyname, value)
    begin
      dscl '.', '-merge', "/#{path}/#{username}", keyname, value
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not set the dscl #{keyname} key with value: #{value} - #{detail.inspect}", detail.backtrace
    end
  end

  # Create the new user with dscl
  def create_new_user(username)
    dscl '.', '-create',  "/Users/#{username}"
  end

  # Get the next available uid on the system by getting a list of user ids,
  # sorting them, grabbing the last one, and adding a 1. Scientific stuff here.
  def next_system_id(min_id=20)
    dscl_output = dscl '.', '-list', '/Users', 'uid'
    # We're ok with throwing away negative uids here. Also, remove nil values.
    user_ids = dscl_output.split.compact.collect { |l| l.to_i if l.match(/^\d+$/) }
    ids = user_ids.compact!.sort! { |a,b| a.to_f <=> b.to_f }
    # We're just looking for an unused id in our sorted array.
    ids.each_index do |i|
      next_id = ids[i] + 1
      return next_id if ids[i+1] != next_id and next_id >= min_id
    end
  end

  # This method is only called on version 10.7 or greater. On 10.7 machines,
  # passwords are set using a salted-SHA512 hash, and on 10.8 machines,
  # passwords are set using PBKDF2. It's possible to have users on 10.8
  # who have upgraded from 10.7 and thus have a salted-SHA512 password hash.
  # If we encounter this, do what 10.8 does - remove that key and give them
  # a 10.8-style PBKDF2 password.
  def write_password_to_users_plist(value)
    users_plist = get_users_plist(@resource.name)
    shadow_hash_data = get_shadow_hash_data(users_plist)
    if self.class.get_os_version == '10.7'
      set_salted_sha512(users_plist, shadow_hash_data, value)
    else
      # It's possible that a user could exist on the system and NOT have
      # a ShadowHashData key (especially if the system was upgraded from 10.6).
      # In this case, a conditional check is needed to determine if the
      # shadow_hash_data variable is a Hash (it would be false if the key
      # didn't exist for this user on the system). If the shadow_hash_data
      # variable IS a Hash and contains the 'SALTED-SHA512' key (indicating an
      # older 10.7-style password hash), it will be deleted and a newer
      # 10.8-style (PBKDF2) password hash will be generated.
      if (shadow_hash_data.class == Hash) && (shadow_hash_data.has_key?('SALTED-SHA512'))
        shadow_hash_data.delete('SALTED-SHA512')
      end
      set_salted_pbkdf2(users_plist, shadow_hash_data, 'entropy', value)
    end
  end

  def flush_dscl_cache
    dscacheutil '-flushcache'
  end

  def get_users_plist(username)
    # This method will retrieve the data stored in a user's plist and
    # return it as a native Ruby hash.
    path = "#{users_plist_dir}/#{username}.plist"
    Puppet::Util::Plist.read_plist_file(path)
  end

  # This method will return the binary plist that's embedded in the
  # ShadowHashData key of a user's plist, or false if it doesn't exist.
  def get_shadow_hash_data(users_plist)
    if users_plist['ShadowHashData']
      password_hash_plist  = users_plist['ShadowHashData'][0]
      self.class.convert_binary_to_hash(password_hash_plist)
    else
      false
    end
  end

  # This method will embed the binary plist data comprising the user's
  # password hash (and Salt/Iterations value if the OS is 10.8 or greater)
  # into the ShadowHashData key of the user's plist.
  def set_shadow_hash_data(users_plist, binary_plist)
    if users_plist.has_key?('ShadowHashData')
      users_plist['ShadowHashData'][0] = binary_plist
    else
      users_plist['ShadowHashData'] = [binary_plist]
    end
    write_users_plist_to_disk(users_plist)
  end

  # This method accepts an argument of a hex password hash, and base64
  # decodes it into a format that OS X 10.7 and 10.8 will store
  # in the user's plist.
  def base64_decode_string(value)
    Base64.decode64([[value].pack("H*")].pack("m").strip)
  end

  # Puppet requires a salted-sha512 password hash for 10.7 users to be passed
  # in Hex, but the embedded plist stores that value as a Base64 encoded
  # string. This method converts the string and calls the
  # set_shadow_hash_data method to serialize and write the plist to disk.
  def set_salted_sha512(users_plist, shadow_hash_data, value)
    unless shadow_hash_data
      shadow_hash_data = Hash.new
      shadow_hash_data['SALTED-SHA512'] = ''
    end
    shadow_hash_data['SALTED-SHA512'] = base64_decode_string(value)
    binary_plist = self.class.convert_hash_to_binary(shadow_hash_data)
    set_shadow_hash_data(users_plist, binary_plist)
  end

  # This method accepts a passed value and one of three fields: 'salt',
  # 'entropy', or 'iterations'.  These fields correspond with the fields
  # utilized in a PBKDF2 password hashing system
  # (see https://en.wikipedia.org/wiki/PBKDF2 ) where 'entropy' is the
  # password hash, 'salt' is the password hash salt value, and 'iterations'
  # is an integer recommended to be > 10,000. The remaining arguments are
  # the user's plist itself, and the shadow_hash_data hash containing the
  # existing PBKDF2 values.
  def set_salted_pbkdf2(users_plist, shadow_hash_data, field, value)
    shadow_hash_data = Hash.new unless shadow_hash_data
    shadow_hash_data['SALTED-SHA512-PBKDF2'] = Hash.new unless shadow_hash_data['SALTED-SHA512-PBKDF2']
    case field
    when 'salt', 'entropy'
      shadow_hash_data['SALTED-SHA512-PBKDF2'][field] = base64_decode_string(value)
    when 'iterations'
      shadow_hash_data['SALTED-SHA512-PBKDF2'][field] = Integer(value)
    else
      raise Puppet::Error "Puppet has tried to set an incorrect field for the 'SALTED-SHA512-PBKDF2' hash. Acceptable fields are 'salt', 'entropy', or 'iterations'."
    end

    # on 10.8, this field *must* contain 8 stars, or authentication will
    # fail.
    users_plist['passwd'] = ('*' * 8)

    # Convert shadow_hash_data to a binary plist, and call the
    # set_shadow_hash_data method to serialize and write the data
    # back to the user's plist.
    binary_plist = self.class.convert_hash_to_binary(shadow_hash_data)
    set_shadow_hash_data(users_plist, binary_plist)
  end

  # This method will accept a plist in XML format, save it to disk, convert
  # the plist to a binary format, and flush the dscl cache.
  def write_users_plist_to_disk(users_plist)
    Puppet::Util::Plist.write_plist_file(users_plist, "#{users_plist_dir}/#{@resource.name}.plist", :binary)
  end

  # This is a simple wrapper method for writing values to a file.
  def write_to_file(filename, value)
    begin
      File.open(filename, 'w') { |f| f.write(value)}
    rescue Errno::EACCES => detail
      raise Puppet::Error, "Could not write to file #{filename}: #{detail}", detail.backtrace
    end
  end
end
