module Puppet
    newtype(:tidy, :parent => Puppet.type(:file)) do
        @doc = "Remove unwanted files based on specific criteria.  Multiple
            criteria are OR'd together, so a file that is too large but is not
            old enough will still get tidied."

        newparam(:path) do
            desc "The path to the file or directory to manage.  Must be fully
                qualified."
            isnamevar
        end

        newparam(:matches) do
            desc "One or more file glob patterns, which restrict the list of
                files to be tidied to those whose basenames match at least one
                of the patterns specified.  Multiple patterns can be specified
                using an array."
        end

        copyparam(Puppet.type(:file), :backup)
        
        newproperty(:ensure) do
            desc "An internal attribute used to determine which files should be removed."

            @nodoc = true
            
            TATTRS = [:age, :size]
            
            defaultto :anything # just so we always get this property

            def change_to_s(currentvalue, newvalue)
                start = "Tidying"
                if @out.include?(:age)
                    start += ", older than %s seconds" % @resource.should(:age)
                end
                if @out.include?(:size)
                    start += ", larger than %s bytes" % @resource.should(:size)
                end

                start
            end

            def insync?(is)
                if is.is_a?(Symbol)
                    if [:absent, :notidy].include?(is)
                        return true
                    else
                        return false
                    end
                else
                    @out = []
                    if @resource[:matches]
                        basename = File.basename(@resource[:path])
                        flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
                        unless @resource[:matches].any? {|pattern| File.fnmatch(pattern, basename, flags) }
                            self.debug "No patterns specified match basename, skipping"
                            return true
                        end
                    end
                    TATTRS.each do |param|
                        if property = @resource.property(param)
                            self.debug "No is value for %s", [param] if is[property].nil?
                            unless property.insync?(is[property])
                                @out << param
                            end
                        end
                    end
                    
                    if @out.length > 0
                        return false
                    else
                        return true
                    end
                end
            end
            
            def retrieve
                stat = nil
                unless stat = @resource.stat
                    return { self => :absent}
                end
                
                if stat.ftype == "directory" and ! @resource[:rmdirs]
                    return {self => :notidy}
                end

                allprops = TATTRS.inject({}) { |prophash, param|
                    if property = @resource.property(param)
                        prophash[property] = property.assess(stat)
                    end
                    prophash
                }
                return { self => allprops } 
            end

            def sync
                file = @resource[:path]
                case File.lstat(file).ftype
                when "directory":
                    if @resource[:rmdirs]
                        subs = Dir.entries(@resource[:path]).reject { |d|
                            d == "." or d == ".."
                        }.length
                        if subs > 0
                            self.info "%s has %s children; not tidying" %
                                [@resource[:path], subs]
                            self.info Dir.entries(@resource[:path]).inspect
                        else
                            Dir.rmdir(@resource[:path])
                        end
                    else
                        self.debug "Not tidying directories"
                        return nil
                    end
                when "file":
                    @resource.handlebackup(file)
                    File.unlink(file)
                when "link":
                    File.unlink(file)
                else
                    self.fail "Cannot tidy files of type %s" %
                        File.lstat(file).ftype
                end

                return :file_tidied
            end
        end

        newproperty(:age) do
            desc "Tidy files whose age is equal to or greater than
                the specified time.  You can choose seconds, minutes,
                hours, days, or weeks by specifying the first letter of any
                of those words (e.g., '1w')."

            @@ageconvertors = {
                :s => 1,
                :m => 60
            }

            @@ageconvertors[:h] = @@ageconvertors[:m] * 60
            @@ageconvertors[:d] = @@ageconvertors[:h] * 24
            @@ageconvertors[:w] = @@ageconvertors[:d] * 7

            def assess(stat)
                type = nil
                if stat.ftype == "directory"
                    type = :mtime
                else
                    type = @resource[:type] || :atime
                end
                
                return stat.send(type).to_i
            end

            def convert(unit, multi)
                if num = @@ageconvertors[unit]
                    return num * multi
                else
                    self.fail "Invalid age unit '%s'" % unit
                end
            end

            def insync?(is)
                if (Time.now.to_i - is) > self.should
                    return false
                end

                true
            end

            munge do |age|
                unit = multi = nil
                case age
                when /^([0-9]+)(\w)\w*$/:
                    multi = Integer($1)
                    unit = $2.downcase.intern
                when /^([0-9]+)$/:
                    multi = Integer($1)
                    unit = :d
                else
                    self.fail "Invalid tidy age %s" % age
                end

                convert(unit, multi)
            end
        end

        newproperty(:size) do
            desc "Tidy files whose size is equal to or greater than
                the specified size.  Unqualified values are in kilobytes, but
                *b*, *k*, and *m* can be appended to specify *bytes*, *kilobytes*,
                and *megabytes*, respectively.  Only the first character is
                significant, so the full word can also be used."

            @@sizeconvertors = {
                :b => 0,
                :k => 1,
                :m => 2,
                :g => 3
            }

            # Retrieve the size from a File::Stat object
            def assess(stat)
                return stat.size
            end

            def convert(unit, multi)
                if num = @@sizeconvertors[unit]
                    result = multi
                    num.times do result *= 1024 end
                    return result
                else
                    self.fail "Invalid size unit '%s'" % unit
                end
            end
            
            def insync?(is)
                if is > self.should
                    return false
                end

                true
            end
            
            munge do |size|
                case size
                when /^([0-9]+)(\w)\w*$/:
                    multi = Integer($1)
                    unit = $2.downcase.intern
                when /^([0-9]+)$/:
                    multi = Integer($1)
                    unit = :k
                else
                    self.fail "Invalid tidy size %s" % age
                end

                convert(unit, multi)
            end
        end

        newparam(:type) do
            desc "Set the mechanism for determining age."
            
            newvalues(:atime, :mtime, :ctime)

            defaultto :atime
        end

        newparam(:recurse) do
            desc "If target is a directory, recursively descend
                into the directory looking for files to tidy."
        end

        newparam(:rmdirs) do
            desc "Tidy directories in addition to files; that is, remove
                directories whose age is older than the specified criteria.
                This will only remove empty directories, so all contained
                files must also be tidied before a directory gets removed."
        end
        
        # Erase PFile's validate method
        validate do
        end

        def self.instances
            []
        end

        @depthfirst = true

        def initialize(hash)
            super

            unless  @parameters.include?(:age) or
                    @parameters.include?(:size)
                unless FileTest.directory?(self[:path])
                    # don't do size comparisons for directories
                    self.fail "Tidy must specify size, age, or both"
                end
            end

            # only allow backing up into filebuckets
            unless self[:backup].is_a? Puppet::Network::Client.dipper
                self[:backup] = false
            end
        end
        
        def retrieve
            # Our ensure property knows how to retrieve everything for us.
            if obj = @parameters[:ensure] 
                return obj.retrieve
            else
                return {}
            end
        end
        
        # Hack things a bit so we only ever check the ensure property.
        def properties
            []
        end
    end
end

