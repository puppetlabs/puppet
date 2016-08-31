Puppet::Type.type(:project).provide(:projadd) do
  desc "Projadd provider for Solaris projects"

  commands :projadd  => '/usr/sbin/projadd'
  commands :projdel  => '/usr/sbin/projdel'
  commands :projmod  => '/usr/sbin/projmod'
  commands :projects => '/usr/bin/projects'

  defaultfor :operatingsystem => :solaris

  mk_resource_methods

  def self.instances
    # Provider array
    instances = []

    # attributes for current project
    project = {}
    currentproperty = nil

    projects('-l').each_line do |line|
      case line.chomp!
      when /^(\S+)$/
        # Start of new project definition
        if project.include? :name
          # Start of this definition was the end of a project before
          project[:ensure] = :present
          instances << new(project)
          project = {}
        end
        currentproperty = "name"
        propertyvalue = $1
      when /^\s*(\S+)\s*:\s*(.*)$/
        currentproperty = $1
        propertyvalue = $2
      when /^\s+(\S+)$/
        propertyvalue = $1
      else
        warn "Unexpectet line #{line.inspect} while listing projects"
      end

      # Now we have enough information to interpret the output
      case currentproperty
      when "name", "comment","projid"
        propertykey = currentproperty.intern

        # Remove quotes on comment
        propertyvalue.gsub!(/^"(.*?)"$/,'\1') if propertykey == :comment

        project[propertykey] = propertyvalue
      when "users","groups"
        propertykey = currentproperty.intern
        unless propertyvalue == '(none)'
          if project.include? propertykey
            project[propertykey] += ",#{propertyvalue}" # Append to existing
          else
            project[propertykey] = "#{propertyvalue}" # First user/group
          end
        else
          project[propertykey] = ''
        end
      when "attribs"
        propertykey = :attributes
        unless propertyvalue == ''
          project[propertykey] ||= {}
          # Split assignment into key and value.
          (key,value) = propertyvalue.split('=',2)
          project[propertykey][key.intern] = value
        else
          project[propertykey] = {}
        end
      else
        warn "Unknown property #{propertykey} while parsing projects output"
      end
    end
    if project.include? :name
      # When projects -l reaches the last line we need to
      # store the last project we were reading
      project[:ensure] = :present
      instances << new(project)
    end
    instances
  end

  def self.prefetch(projects)
    instances.each do |prov|
      if proj = projects[prov.name]
        proj.provider = prov
      end
    end
  end

  def exists?
    get(:ensure) != :absent
  end

  def create
    args = []
    args << '-c' << resource[:comment] unless resource[:comment].nil?
    args << '-p' << resource[:projid] unless resource[:projid].nil?
    args << '-U' << resource[:users] unless resource[:users].nil? or resource[:users].empty?
    args << '-G' << resource[:groups] unless resource[:groups].nil? or resource[:groups].empty?
    unless resource[:attributes].nil? or resource[:attributes].empty?
      resource[:attributes].each do |k,v|
        if v.nil?
          args << '-K' << "#{k}"
        else
          args << '-K' << "#{k}=#{v}"
        end
      end
    end
    args << resource[:name]
    projadd *args
  end

  def destroy
    projdel resource[:name]
  end

  def projid=(value)
    projmod '-p', value, resource[:name]
  end

  def comment=(value)
    projmod '-c', value, resource[:name]
  end

  def users=(value)
    if value.empty?
      # Remove every existing user
      projmod '-r', '-U', get(:users), resource[:name]
    else
      projmod '-U', value, resource[:name]
    end
  end

  def groups=(value)
    if value.empty?
      # Remove every existing user
      projmod '-r', '-G', get(:groups), resource[:name]
    else
      projmod '-G', value, resource[:name]
    end
  end

  def attributes=(value)
    args = []
    if value.empty?
      args << '-r' # Remove
      get(:attributes).each do |k,v|
        if v.nil?
          args << '-K' << "#{k}"
        else
          args << '-K' << "#{k}=#{v}"
        end
      end
    else
      args << '-s' # Substitute
      value.each do |k,v|
        if v.nil?
          args << '-K' << "#{k}"
        else
          args << '-K' << "#{k}=#{v}"
        end
      end
    end
    args << resource[:name]
    projmod *args
  end

end
