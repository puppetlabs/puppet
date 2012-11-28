require 'puppet'
require 'facter/util/plist'
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
  commands :plutil       => '/usr/bin/plutil'
  commands :dscacheutil  => '/usr/bin/dscacheutil'

  # Provider confines and defaults
  confine    :operatingsystem => :darwin
  defaultfor :operatingsystem => :darwin

  # Need this to create getter/setter methods automagically
  # This command creates methods that return @property_hash[:value]
  mk_resource_methods

  # JJM: OS X can manage passwords.
  has_feature :manages_passwords

  # 10.8 Passwords use a PBKDF2 salt value
  has_features :manages_password_salt

##               ##
## Class Methods ##
##               ##

  def self.ds_to_ns_attribute_map
    # This method exists to map the dscl values to the correct Puppet
    # properties. This stays relatively consistent, but who knows what
    # Apple will do next year...
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

  def self.prefetch(resources)
    # Prefetching is necessary to use @property_hash inside any setter methods.
    # self.prefetch uses self.instances to gather an array of user instances
    # on the system, and then populates the @property_hash instance variable
    # with attribute data for the specific instance in question (i.e. it
    # gathers the 'is' values of the resource into the @property_hash instance
    # variable so you don't have to read from the system every time you need
    # to gather the 'is' values for a resource. The downside here is that
    # populating this instance variable for every resource on the system
    # takes time and front-loads your Puppet run.
    instances.each do |prov|
      if resource = resources[prov.name]
        resource.provider = prov
      end
    end
  end

  def self.instances
    # This method assembles an array of provider instances containing
    # information about every instance of the user type on the system (i.e.
    # every user and its attributes). The `puppet resource` command relies
    # on self.instances to gather an array of user instances in order to
    # display its output.
    get_all_users.collect do |user|
      self.new(generate_attribute_hash(user))
    end
  end

  def self.get_all_users
    # Return an array of hashes containing information about every user on
    # the system.
    Plist.parse_xml(dscl '-plist', '.', 'readall', '/Users')
  end

  def self.generate_attribute_hash(input_hash)
    # This method accepts an individual user plist, passed as a hash, and
    # strips the dsAttrTypeStandard: prefix that dscl adds for each key.
    # An attribute hash is assembled and returned from the properties
    # supported by the user type.
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
    if (Puppet::Util::Package.versioncmp(get_os_version, '10.7') == -1)
      attribute_hash[:password] = get_sha1(attribute_hash[:guid])
    else
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
    end

    attribute_hash
  end

  def self.get_os_version
    @os_version ||= Facter.value(:macosx_productversion_major)
  end

  def self.get_list_of_groups
    # Use dscl to retrieve an array of hashes containing attributes about all
    # of the local groups on the machine.
    @groups ||= Plist.parse_xml(dscl '-plist', '.', 'readall', '/Groups')
  end

  def self.get_attribute_from_dscl(path, username, keyname)
    # Perform a dscl lookup at the path specified for the specific keyname
    # value. The value returned is the first item within the array returned
    # from dscl
    Plist.parse_xml(dscl '-plist', '.', 'read', "/#{path}/#{username}", keyname)
  end

  def self.get_embedded_binary_plist(shadow_hash_data)
    # The plist embedded in the ShadowHashData key is a binary plist. The
    # facter/util/plist library doesn't read binary plists, so we need to
    # extract the binary plist, convert it to XML, and return it.
    embedded_binary_plist = Array(shadow_hash_data['dsAttrTypeNative:ShadowHashData'][0].delete(' ')).pack('H*')
    convert_binary_to_xml(embedded_binary_plist)
  end

  def self.convert_xml_to_binary(plist_data)
    # This method will accept a hash that has been returned from Plist::parse_xml
    # and convert it to a binary plist (string value).
    Puppet.debug('Converting XML plist to binary')
    Puppet.debug('Executing: \'plutil -convert binary1 -o - -\'')
    IO.popen('plutil -convert binary1 -o - -', mode='r+') do |io|
      io.write Plist::Emit.dump(plist_data)
      io.close_write
      @converted_plist = io.read
    end
    @converted_plist
  end

  def self.convert_binary_to_xml(plist_data)
    # This method will accept a binary plist (as a string) and convert it to a
    # hash via Plist::parse_xml.
    Puppet.debug('Converting binary plist to XML')
    Puppet.debug('Executing: \'plutil -convert xml1 -o - -\'')
    IO.popen('plutil -convert xml1 -o - -', mode='r+') do |io|
      io.write plist_data
      io.close_write
      @converted_plist = io.read
    end
    Puppet.debug('Converting XML values to a hash.')
    Plist::parse_xml(@converted_plist)
  end

  def self.get_salted_sha512(embedded_binary_plist)
    # The salted-SHA512 password hash in 10.7 is stored in the 'SALTED-SHA512'
    # key as binary data. That data is extracted and converted to a hex string.
    embedded_binary_plist['SALTED-SHA512'].string.unpack("H*")[0]
  end

  def self.get_salted_sha512_pbkdf2(field, embedded_binary_plist)
    # This method reads the passed embedded_binary_plist hash and returns values
    # according to which field is passed.  Arguments passed are the hash
    # containing the value read from the 'ShadowHashData' key in the User's
    # plist, and the field to be read (one of 'entropy', 'salt', or 'iterations')
    case field
    when 'salt', 'entropy'
      embedded_binary_plist['SALTED-SHA512-PBKDF2'][field].string.unpack('H*').first
    when 'iterations'
      Integer(embedded_binary_plist['SALTED-SHA512-PBKDF2'][field])
    else
      raise Puppet::Error, 'Puppet has tried to read an incorrect value from the ' +
           "SALTED-SHA512-PBKDF2 hash. Acceptable fields are 'salt', " +
           "'entropy', or 'iterations'."
    end
  end

  def self.get_sha1(guid)
    # In versions 10.5 and 10.6 of OS X, the password hash is stored in a file
    # in the /var/db/shadow/hash directory that matches the GUID of the user.
    password_hash = nil
    password_hash_file = "#{password_hash_dir}/#{guid}"
    if File.exists?(password_hash_file) and File.file?(password_hash_file)
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

  def create
    # This method is called if ensure => present is passed and the exists?
    # method returns false. Dscl will directly set most values, but the
    # setter methods will be used for any exceptions.
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

      # If a non-numerical gid value is passed, assume it is a group name and
      # lookup that group's GID value to use when setting the GID
      if (attribute == :gid) and value.class == 'Fixnum'
        value = self.class.get_attribute_from_dscl('Groups', value, 'PrimaryGroupID')['dsAttrTypeStandard:PrimaryGroupID'][0]
      end

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

  def delete
    # This method is called when ensure => absent has been set.
    # Deleting a user is handled by dscl
    dscl '.', '-delete', "/Users/#{@resource.name}"
  end

##                       ##
## Getter/Setter Methods ##
##                       ##

  def groups=(value)
    # In the setter method we're only going to take action on groups for which
    # the user is not currently a member.
    guid = self.class.get_attribute_from_dscl('Users', @resource.name, 'GeneratedUID')['dsAttrTypeStandard:GeneratedUID'][0]
    groups_to_add = value.split(',') - groups.split(',')
    groups_to_add.each do |group|
      merge_attribute_with_dscl('Groups', group, 'GroupMembership', @resource.name)
      merge_attribute_with_dscl('Groups', group, 'GroupMembers', guid)
    end
  end

  def password=(value)
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
    if (Puppet::Util::Package.versioncmp(self.class.get_os_version, '10.7') == -1)
      write_sha1_hash(value)
    else
      if self.class.get_os_version == '10.7'
        if value.length != 136
          raise Puppet::Error, "OS X 10.7 requires a Salted SHA512 hash password of 136 characters.  Please check your password and try again."
        end
      else
        if value.length != 256
           raise Puppet::Error, "OS X versions > 10.7 require a Salted SHA512 PBKDF2 password hash of 256 characters. Please check your password and try again."
        end
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
  end

  def iterations=(value)
    # The iterations and salt properties, like the password property, can only
    # be modified by directly changing the user's plist. Because of this fact,
    # we have to treat the ds cache just like you would in the password=
    # method.
    if (Puppet::Util::Package.versioncmp(self.class.get_os_version, '10.7') > 0)
      sleep 2
      flush_dscl_cache
      users_plist = get_users_plist(@resource.name)
      shadow_hash_data = get_shadow_hash_data(users_plist)
      set_salted_pbkdf2(users_plist, shadow_hash_data, 'iterations', value)
      flush_dscl_cache
    end
  end

  def salt=(value)
    # The iterations and salt properties, like the password property, can only
    # be modified by directly changing the user's plist. Because of this fact,
    # we have to treat the ds cache just like you would in the password=
    # method.
    if (Puppet::Util::Package.versioncmp(self.class.get_os_version, '10.7') > 0)
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
               "#{@resource.name} due to the following error: #{e.inspect}"
        end
      else
        begin
          dscl '.', '-merge', "/Users/#{resource.name}", self.class.ns_to_ds_attribute_map[setter_method.intern], value
        rescue Puppet::ExecutionFailure => e
          raise Puppet::Error, "Cannot set the #{setter_method} value of '#{value}' for user " +
               "#{@resource.name} due to the following error: #{e.inspect}"
        end
      end
    end
  end


  ##                ##
  ## Helper Methods ##
  ##                ##

  def users_plist_dir
    '/var/db/dslocal/nodes/Default/users'
  end

  def self.password_hash_dir
    '/var/db/shadow/hash'
  end

  def merge_attribute_with_dscl(path, username, keyname, value)
    # This method will merge in a given value using dscl
    begin
      dscl '.', '-merge', "/#{path}/#{username}", keyname, value
    rescue Puppet::ExecutionFailure => detail
      raise Puppet::Error, "Could not set the dscl #{keyname} key with value: #{value} - #{detail.inspect}"
    end
  end

  def create_new_user(username)
    # Create the new user with dscl
    dscl '.', '-create',  "/Users/#{username}"
  end

  def next_system_id(min_id=20)
    # Get the next available uid on the system by getting a list of user ids,
    # sorting them, grabbing the last one, and adding a 1. Scientific stuff here.
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

  def write_password_to_users_plist(value)
  #  # This method is only called on version 10.7 or greater. On 10.7 machines,
  #  # passwords are set using a salted-SHA512 hash, and on 10.8 machines,
  #  # passwords are set using PBKDF2. It's possible to have users on 10.8
  #  # who have upgraded from 10.7 and thus have a salted-SHA512 password hash.
  #  # If we encounter this, do what 10.8 does - remove that key and give them
  #  # a 10.8-style PBKDF2 password.
    users_plist = get_users_plist(@resource.name)
    shadow_hash_data = get_shadow_hash_data(users_plist)
    if self.class.get_os_version == '10.7'
      set_salted_sha512(users_plist, shadow_hash_data, value)
    else
      shadow_hash_data.delete('SALTED-SHA512') if shadow_hash_data['SALTED-SHA512']
      set_salted_pbkdf2(users_plist, shadow_hash_data, 'entropy', value)
    end
  end

  def flush_dscl_cache
    dscacheutil '-flushcache'
  end

  def get_users_plist(username)
    # This method will retrieve the data stored in a user's plist and
    # return it as a native Ruby hash.
    Plist::parse_xml(plutil('-convert', 'xml1', '-o', '/dev/stdout', "#{users_plist_dir}/#{username}.plist"))
  end

  def get_shadow_hash_data(users_plist)
    # This method will return the binary plist that's embedded in the
    # ShadowHashData key of a user's plist, or false if it doesn't exist.
    if users_plist['ShadowHashData']
      password_hash_plist  = users_plist['ShadowHashData'][0].string
      self.class.convert_binary_to_xml(password_hash_plist)
    else
      false
    end
  end

  def set_shadow_hash_data(users_plist, binary_plist)
    # This method will embed the binary plist data comprising the user's
    # password hash (and Salt/Iterations value if the OS is 10.8 or greater)
    # into the ShadowHashData key of the user's plist.
    if users_plist.has_key?('ShadowHashData')
      users_plist['ShadowHashData'][0].string = binary_plist
    else
      users_plist['ShadowHashData'] = [StringIO.new(binary_plist)]
    end
    write_users_plist_to_disk(users_plist)
  end

  def set_salted_sha512(users_plist, shadow_hash_data, value)
    # Puppet requires a salted-sha512 password hash for 10.7 users to be passed
    # in Hex, but the embedded plist stores that value as a Base64 encoded
    # string. This method converts the string and calls the
    # set_shadow_hash_data method to serialize and write the plist to disk.
    unless shadow_hash_data
      shadow_hash_data = Hash.new
      shadow_hash_data['SALTED-SHA512'] = StringIO.new
    end
    shadow_hash_data['SALTED-SHA512'].string = Base64.decode64([[value].pack("H*")].pack("m").strip)
    binary_plist = self.class.convert_xml_to_binary(shadow_hash_data)
    set_shadow_hash_data(users_plist, binary_plist)
  end

  def set_salted_pbkdf2(users_plist, shadow_hash_data, field, value)
    # This method accepts a passed value and one of three fields: 'salt',
    # 'entropy', or 'iterations'.  These fields correspond with the fields
    # utilized in a PBKDF2 password hashing system
    # (see http://en.wikipedia.org/wiki/PBKDF2 ) where 'entropy' is the
    # password hash, 'salt' is the password hash salt value, and 'iterations'
    # is an integer recommended to be > 10,000. The remaining arguments are
    # the user's plist itself, and the shadow_hash_data hash containing the
    # existing PBKDF2 values.
    shadow_hash_data = Hash.new unless shadow_hash_data
    shadow_hash_data['SALTED-SHA512-PBKDF2'] = Hash.new unless shadow_hash_data['SALTED-SHA512-PBKDF2']
    case field
    when 'salt', 'entropy'
      shadow_hash_data['SALTED-SHA512-PBKDF2'][field] =  StringIO.new unless shadow_hash_data['SALTED-SHA512-PBKDF2'][field]
      shadow_hash_data['SALTED-SHA512-PBKDF2'][field].string = Base64.decode64([[value].pack("H*")].pack("m").strip)
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
    binary_plist = self.class.convert_xml_to_binary(shadow_hash_data)
    set_shadow_hash_data(users_plist, binary_plist)
  end

  def write_users_plist_to_disk(users_plist)
    # This method will accept a plist in XML format, save it to disk, convert
    # the plist to a binary format, and flush the dscl cache.
    Plist::Emit.save_plist(users_plist, "#{users_plist_dir}/#{@resource.name}.plist")
    plutil'-convert', 'binary1', "#{users_plist_dir}/#{@resource.name}.plist"
  end

  def write_to_file(filename, value)
    # This is a simple wrapper method for writing values to a file.
    begin
      File.open(filename, 'w') { |f| f.write(value)}
    rescue Errno::EACCES => detail
      raise Puppet::Error, "Could not write to file #{filename}: #{detail}"
    end
  end

  def write_sha1_hash(value)
    users_guid = self.class.get_attribute_from_dscl('Users', @resource.name, 'GeneratedUID')['dsAttrTypeStandard:GeneratedUID'][0]
    password_hash_file = "#{self.class.password_hash_dir}/#{users_guid}"
    write_to_file(password_hash_file, value)

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

    merge_attribute_with_dscl('Users', @resource.name, 'AuthenticationAuthority', ';ShadowHash;')
  end
end
