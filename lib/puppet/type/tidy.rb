
require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    newtype(:tidy, Puppet.type(:file)) do
        @doc = "Remove unwanted files based on specific criteria.  Multiple
            criteria or OR'd together, so a file that is too large but is not
            old enough will still get tidied."

        newparam(:path) do
            desc "The path to the file or directory to manage.  Must be fully
                qualified."
            isnamevar
        end

        copyparam(Puppet.type(:file), :backup)

        newparam(:age) do
            desc "Tidy files whose age is equal to or greater than
                the specified number of days.  You can choose seconds, minutes,
                hours, days, or weeks by specifying the first letter of any
                of those words (e.g., '1w')."

            @@ageconvertors = {
                :s => 1,
                :m => 60
            }

            @@ageconvertors[:h] = @@ageconvertors[:m] * 60
            @@ageconvertors[:d] = @@ageconvertors[:h] * 24
            @@ageconvertors[:w] = @@ageconvertors[:d] * 7

            def convert(unit, multi)
                if num = @@ageconvertors[unit]
                    return num * multi
                else
                    self.fail "Invalid age unit '%s'" % unit
                end
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

        newparam(:size) do
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

            def convert(unit, multi)
                if num = @@sizeconvertors[unit]
                    result = multi
                    num.times do result *= 1024 end
                    return result
                else
                    self.fail "Invalid size unit '%s'" % unit
                end
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

        newstate(:tidyup) do
            require 'etc'

            @nodoc = true
            @name = :tidyup

            def age(stat)
                type = nil
                if stat.ftype == "directory"
                    type = :mtime
                else
                    type = @parent[:type] || :atime
                end
                
                #return Integer(Time.now - stat.send(type))
                return stat.send(type).to_i
            end

            def change_to_s
                start = "Tidying"
                unless insync_age?
                    start += ", older than %s seconds" % @parent[:age]
                end
                unless insync_size?
                    start += ", larger than %s bytes" % @parent[:size]
                end

                start
            end

            def insync_age?
                if num = @parent[:age] and @is[0]
                    if (Time.now.to_i - @is[0]) > num
                        return false
                    end
                end

                true
            end

            def insync_size?
                if num = @parent[:size] and @is[1]
                    if @is[1] > num
                        return false
                    end
                end

                true
            end

            def insync?
                insync_age? and insync_size?
            end

            def retrieve
                stat = nil
                unless stat = @parent.stat
                    @is = :unknown
                    return
                end

                @is = [:age, :size].collect { |param|
                    if @parent[param]
                        self.send(param, stat)
                    end
                }.reject { |p| p == false or p.nil? }
            end

            def size(stat)
                return stat.size
            end

            def sync
                file = @parent[:path]
                case File.lstat(file).ftype
                when "directory":
                    if @parent[:rmdirs]
                        subs = Dir.entries(@parent[:path]).reject { |d|
                            d == "." or d == ".."
                        }.length
                        if subs > 0
                            self.info "%s has %s children; not tidying" %
                                [@parent[:path], subs]
                            self.info Dir.entries(@parent[:path]).inspect
                        else
                            Dir.rmdir(@parent[:path])
                        end
                    else
                        self.debug "Not tidying directories"
                        return nil
                    end
                when "file":
                    @parent.handlebackup(file)
                    File.unlink(file)
                when "link":     File.unlink(file)
                else
                    self.fail "Cannot tidy files of type %s" %
                        File.lstat(file).ftype
                end

                return :file_tidied
            end
        end

        # Erase PFile's validate method
        validate do
        end

        def self.list
            self.collect { |t| t }
        end

        @depthfirst = true

        def initialize(hash)
            super
            #self.setdefaults

            unless  @parameters.include?(:age) or
                    @parameters.include?(:size)
                unless FileTest.directory?(self[:path])
                    # don't do size comparisons for directories
                    self.fail "Tidy must specify size, age, or both"
                end
            end

            # only allow backing up into filebuckets
            unless self[:backup].is_a? Puppet::Client::Dipper
                self[:backup] = false
            end
            self[:tidyup] = [:age, :size].collect { |param|
                self[param]
            }.reject { |p| p == false }
        end

    end
end

# $Id$
