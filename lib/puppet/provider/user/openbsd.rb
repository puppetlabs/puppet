require 'puppet/error'

Puppet::Type.type(:user).provide :openbsd, :parent => :useradd do
  desc "User management via `useradd` and its ilk for OpenBSD. Note that you
    will need to install Ruby's shadow password library (package known as
    `ruby-shadow`) if you wish to manage user passwords."

  commands :add      => "useradd",
           :delete   => "userdel",
           :modify   => "usermod",
           :password => "passwd"

  defaultfor :operatingsystem => :openbsd
  confine    :operatingsystem => :openbsd

  options :home, :flag => "-d", :method => :dir
  options :comment, :method => :gecos
  options :groups, :flag => "-G"
  options :password, :method => :sp_pwdp
  options :loginclass, :flag => '-L', :method => :sp_loginclass
  options :expiry, :method => :sp_expire,
    :munge => proc { |value|
      if value == :absent
        ''
      else
        # OpenBSD uses a format like "january 1 1970"
        Time.parse(value).strftime('%B %d %Y')
      end
    },
    :unmunge => proc { |value|
      if value == -1
        :absent
      else
        # Expiry is days after 1970-01-01
        (Date.new(1970,1,1) + value).strftime('%Y-%m-%d')
      end
    }

  [:expiry, :password, :loginclass].each do |shadow_property|
    define_method(shadow_property) do
      if Puppet.features.libshadow?
        if ent = Shadow::Passwd.getspnam(@resource.name)
          method = self.class.option(shadow_property, :method)
          # ruby-shadow may not be new enough (< 2.4.1) and therefore lack the
          # sp_loginclass field.
          begin
            return unmunge(shadow_property, ent.send(method))
          rescue => detail
            Puppet.warning "ruby-shadow doesn't support #{method}"
          end
        end
      end
      :absent
    end
  end

  has_features :manages_homedir, :manages_expiry, :system_users
  has_features :manages_shell
  if Puppet.features.libshadow?
    has_features :manages_passwords, :manages_loginclass
  end

  def loginclass=(value)
    set("loginclass", value)
  end

  def modifycmd(param, value)
    cmd = super
    if param == :groups
      idx = cmd.index('-G')
      cmd[idx] = '-S'
    end
    cmd
  end
end
