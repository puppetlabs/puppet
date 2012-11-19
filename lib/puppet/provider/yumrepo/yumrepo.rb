require 'fileutils'
require 'ruby-debug'

Puppet::Type.type(:yumrepo).provide(:yumrepo) do
  desc "Manage yum repositories"
  mk_resource_methods

  def create
    desired_yumconfig.store
  end

  def destroy
    File.delete resource.section.file
  end

  def exists?
    repo_in_default_location? || repo_in_other_location?(get_reposdir)
  end

  def get_reposdir
    file = Puppet::Util::IniConfig::File.new 
    file.read("/etc/yum.conf")
    file.each_section { |section| return section["reposdir"] unless section["reposdir"].nil? }
    "/etc/yum.repos.d/"
  end

  # Returns true if repo is in repos directory/name_repo.repo (most likely case)
  def repo_in_default_location?
    file = Puppet::Util::IniConfig::File.new
    file.read(resource.section.file)
    file.include?(resource.name)
  end

  def repo_in_other_location?(reposdir)
    file_names = Dir.entries(reposdir)
    file_names.delete '.'
    file_names.delete '..'
    file = Puppet::Util::IniConfig::File.new 

    file_names.each do |repo|
      file.read(repo)
      file.each_section { |section| return true if section.name == resource.name } #repo found!
    end
    
    false
  end

  def desired_yumconfig
    yumconfig = Puppet::Util::IniConfig::File.new
    yumconfig.read("#{resource.section.file}")

    section = resource[:name]
    yumconfig.each_file { |f| yumconfig.add_section(section,f) }

    options = [
      :baseurl,
      :descr,
      :enabled,
      :enablegroups,
      :exclude,
      :failovermethod,
      :gpgcheck,
      :gpgkey,
      :includepkgs,
      :http_caching,
      :keepalive,
      :metadata_expire,
      :mirrorlist,
      :priority,
      :protect,
      :proxy,
      :proxy_password,
      :proxy_username,
      :timeout,
    ]

    options.each do |option|
      if resource[option].nil?
        next
      else
        if option == :gpgkey
          yumconfig[section][option.to_s] = resource[option].to_s if resource[:gpgcheck] == 1
        else
          yumconfig[section][option.to_s] = resource[option].to_s unless resource[option].to_s == 'absent'
        end
      end
    end

    return yumconfig
  end

end 
