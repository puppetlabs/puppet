require 'puppet/util/user_attr'

Puppet::Type.type(:user).provide :user_role_add, :parent => :useradd, :source => :useradd do

    desc "User management inherits ``useradd`` and adds logic to manage roles on Solaris using roleadd."

    defaultfor :operatingsystem => :solaris

    commands :add => "useradd", :delete => "userdel", :modify => "usermod", :role_add => "roleadd", :role_delete => "roledel", :role_modify => "rolemod"
    options :home, :flag => "-d", :method => :dir
    options :comment, :method => :gecos
    options :groups, :flag => "-G"
    options :roles, :flag => "-R"
    options :auths, :flag => "-A"
    options :profiles, :flag => "-P"

    verify :gid, "GID must be an integer" do |value|
        value.is_a? Integer
    end

    verify :groups, "Groups must be comma-separated" do |value|
        value !~ /\s/
    end

    has_features :manages_homedir, :allows_duplicates, :manages_solaris_rbac, :manages_passwords

    #must override this to hand the keyvalue pairs
    def add_properties
        cmd = []
        Puppet::Type.type(:user).validproperties.each do |property|
            #skip the password because we can't create it with the solaris useradd
            next if [:ensure, :password].include?(property)
            # 1680 Now you can set the hashed passwords on solaris:lib/puppet/provider/user/user_role_add.rb
            # the value needs to be quoted, mostly because -c might
            # have spaces in it
            if value = @resource.should(property) and value != ""
                if property == :keys
                    cmd += build_keys_cmd(value)
                else
                    cmd << flag(property) << value
                end
            end
        end
        cmd
    end

    def user_attributes
        @user_attributes ||= UserAttr.get_attributes_by_name(@resource[:name])
    end

    def flush
        @user_attributes = nil
    end

    def command(cmd)
        if is_role? or (!exists? and @resource[:ensure] == :role)
            cmd = ("role_" + cmd.to_s).intern
        end
        super(cmd)
    end

    def is_role?
        user_attributes and user_attributes[:type] == "role"
    end

    def run(cmd, msg)
        begin
            execute(cmd)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not %s %s %s: %s" %
                [msg, @resource.class.name, @resource.name, detail]
        end
    end

    def transition(type)
        cmd = [command(:modify)]
        cmd << "-K" << "type=#{type}"
        cmd += add_properties
        cmd << @resource[:name]
    end

    def create
        if is_role?
            run(transition("normal"), "transition role to")
        else
            run(addcmd, "create")
        end
        # added to handle case when password is specified
        if @resource[:password]
            self.password = @resource[:password]
        end
    end

    def destroy
        run(deletecmd, "delete "+ (is_role? ? "role" : "user"))
    end

    def create_role
        if exists? and !is_role?
            run(transition("role"), "transition user to")
        else
            run(addcmd, "create role")
        end
    end

    def roles
        if user_attributes
            user_attributes[:roles]
        end
    end

    def auths
        if user_attributes
            user_attributes[:auths]
        end
    end

    def profiles
        if user_attributes
            user_attributes[:profiles]
        end
    end

    def project
        if user_attributes
            user_attributes[:project]
        end
    end

    def managed_attributes
        [:name, :type, :roles, :auths, :profiles, :project]
    end

    def remove_managed_attributes
        managed = managed_attributes
        user_attributes.select { |k,v| !managed.include?(k) }.inject({}) { |hash, array| hash[array[0]] = array[1]; hash }
    end

    def keys
        if user_attributes
            #we have to get rid of all the keys we are managing another way
            remove_managed_attributes
        end
    end

    def build_keys_cmd(keys_hash)
        cmd = []
        keys_hash.each do |k,v|
            cmd << "-K" << "#{k}=#{v}"
        end
        cmd
    end

    def keys=(keys_hash)
        run([command(:modify)] + build_keys_cmd(keys_hash) << @resource[:name], "modify attribute key pairs")
    end

    #Read in /etc/shadow, find the line for this user (skipping comments, because who knows) and return the hashed pw (the second entry)
    #No abstraction, all esoteric knowledge of file formats, yay
    def password
        #got perl?
        if ary = File.readlines("/etc/shadow").reject { |r| r =~ /^[^\w]/}.collect { |l| l.split(':')[0..1] }.find { |user, passwd| user == @resource[:name] }
            pass = ary[1]
        end
        pass
    end

    #Read in /etc/shadow, find the line for our used and rewrite it with the new pw
    #Smooth like 80 grit
    def password=(cryptopw)
        begin
            File.open("/etc/shadow", "r") do |shadow|
                File.open("/etc/shadow_tmp", "w", 0600) do |shadow_tmp|
                    while line = shadow.gets do
                        line_arr = line.split(':')
                        if line_arr[0] == @resource[:name]
                            line_arr[1] = cryptopw
                            line = line_arr.join(':')
                        end
                        shadow_tmp.print line
                    end
                end
            end
            File.rename("/etc/shadow_tmp", "/etc/shadow")
        rescue => detail
            fail "Could not write temporary shadow file: %s" % detail
        ensure
            # Make sure this *always* gets deleted
            File.unlink("/etc/shadow_tmp") if File.exist?("/etc/shadow_tmp")
        end
    end
end

