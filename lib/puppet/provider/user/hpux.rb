Puppet::Type.type(:user).provide :hpuxuseradd, :parent => :useradd do
  desc "User management for HP-UX. This provider uses the undocumented `-F`
    switch to HP-UX's special `usermod` binary to work around the fact that
    its standard `usermod` cannot make changes while the user is logged in.
    New functionality provides for changing trusted computing passwords and 
    resetting password expirations under trusted computing"

  defaultfor :operatingsystem => "hp-ux"
  confine :operatingsystem => "hp-ux"

  commands :modify => "/usr/sam/lbin/usermod.sam", :delete => "/usr/sam/lbin/userdel.sam", :add => "/usr/sam/lbin/useradd.sam", :password => '/usr/lbin/modprpw', :expiry => '/usr/lbin/modprpw'
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :home, :flag => "-d", :method => :dir
  options :expiry, :method => :expire

  verify :gid, "GID must be an integer" do |value|
    value.is_a? Integer
  end

  verify :groups, "Groups must be comma-separated" do |value|
    value !~ /\s/
  end

  has_features :manages_homedir, :allows_duplicates, :manages_passwords, :manages_password_age, :manages_expiry

  def deletecmd
    super.insert(1,"-F")
  end

  def modifycmd(param,value)
     cmd = super(param, value)
     cmd << "-F"
     if self.trusted == "Trusted"
        cmd << ";"
        cmd << "/usr/lbin/modprpw"
        cmd << "-v"
        cmd << "-l"
        cmd << "#{resource.name}"
     end
     cmd
  end

  def password
    # Password management routine for trusted and non-trusted systems
    #temp=""
    while ent = Etc.getpwent() do
      if ent.name == resource.name
        temp=ent.name
        break
      end
    end
    Etc.endpwent()
    if !temp
      return nil
    end

    ent = Etc.getpwnam(resource.name)
    if ent.passwd == "*"
      # Either no password or trusted password, check trusted
      file_name="/tcb/files/auth/#{resource.name.chars.first}/#{resource.name}"
      if File.file?(file_name)
        # Found the tcb user for the specific user, now get passwd
        File.open(file_name).each do |line|
          if ( line =~ /u_pwd/ )
            temp_passwd=line.split(":")[1].split("=")[1]
            ent.passwd = temp_passwd
            return ent.passwd
          end
        end
      else
        debug "No trusted computing user file #{file_name} found."
      end
    else
      return ent.passwd
    end
  end

  def trusted
      trusted_sys = %x(/usr/lbin/getprpw root 2>&1)
      if trusted_sys.chomp == "System is not trusted."
         "NotTrusted"
      else
         "Trusted"
      end
  end

  def trust2
      trusted_sys = %x(/usr/lbin/getprpw root 2>&1)
      if trusted_sys.chomp == "System is not trusted."
         false
      else
         true
      end
  end

  def password_min_age
    ent= Etc.getpwnam(resource.name)
    temp = %x( /usr/lbin/getprdef -m mintm ).chomp
    mintm = temp[/mintm=(.*)/, 1]
    if mintm == ""
       return nil
    else
       return mintm
    end
  end

  def password_max_age
    temp = %x( /usr/lbin/getprdef -m exptm ).chomp
    maxtm = temp[/exptm=(.*)/,1 ]
    if maxtm == ""
       return nil
    else
       return maxtm
    end
  end
end
