
require 'etc'
require 'puppet/type/state'
require 'puppet/type/pfile'

module Puppet
    newtype(:tidy, Puppet.type(:file)) do
        @doc = "Remove unwanted files based on specific criteria."

        newparam(:path) do
            desc "The path to the file to manage.  Must be fully qualified."
            isnamevar
        end

        copyparam(Puppet.type(:file), :backup)

        newparam(:age) do
            desc "Tidy files whose age is equal to or greater than
                the specified number of days."

            munge do |age|
                case age
                when /^[0-9]+$/, /^[0-9]+[dD]/:
                    Integer(age.gsub(/[^0-9]+/,'')) *
                        60 * 60 * 24
                when /^[0-9]+$/, /^[0-9]+[hH]/:
                    Integer(age.gsub(/[^0-9]+/,'')) * 60 * 60
                when /^[0-9]+[mM]/:
                    Integer(age.gsub(/[^0-9]+/,'')) * 60
                when /^[0-9]+[sS]/:
                    Integer(age.gsub(/[^0-9]+/,''))
                else
                    raise Puppet::Error.new("Invalid tidy age %s" % age)
                end
            end
        end

        newparam(:size) do
            desc "Tidy files whose size is equal to or greater than
                the specified size.  Unqualified values are in kilobytes, but
                *b*, *k*, and *m* can be appended to specify *bytes*, *kilobytes*,
                and *megabytes*, respectively.  Only the first character is
                significant, so the full word can also be used."
            
            munge do |size|
                if FileTest.directory?(@parent[:path])
                    # don't do size comparisons for directories
                    return
                end
                case size
                when /^[0-9]+$/, /^[0-9]+[kK]/:
                    Integer(size.gsub(/[^0-9]+/,'')) * 1024
                when /^[0-9]+[bB]/:
                    Integer(size.gsub(/[^0-9]+/,''))
                when /^[0-9]+[mM]/:
                    Integer(size.gsub(/[^0-9]+/,'')) *
                        1024 * 1024
                else
                    raise Puppet::Error.new("Invalid tidy size %s" % size)
                end
            end
        end

        newparam(:type) do
            desc "Set the mechanism for determining age.  Access
                time is the default mechanism, but modification."
            
            munge do |type|
                case type
                when "atime", "mtime", "ctime":
                    @parameters[:type] = type.intern
                else
                    raise Puppet::Error.new("Invalid tidy type %s" % type)
                end
            end
        end

        newparam(:recurse) do
            desc "If target is a directory, recursively descend
                into the directory looking for files to tidy."
        end

        newparam(:rmdirs) do
            desc "Tidy directories in addition to files."
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
                
                return Integer(Time.now - stat.send(type))
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
                when "symlink":     File.unlink(file)
                else
                    raise Puppet::Error, "Cannot tidy files of type %s" %
                        File.lstat(file).ftype
                end

                return :file_tidied
            end
        end

        @depthfirst = true

        def initialize(hash)
            super

            unless  @parameters.include?(:age) or
                    @parameters.include?(:size)
                unless FileTest.directory?(self[:path])
                    # don't do size comparisons for directories
                    raise Puppet::Error, "Tidy must specify size, age, or both"
                end
            end

            # only allow backing up into filebuckets
            unless self[:backup].is_a? Puppet::Client::Dipper
                self[:backup] = false
            end
            self[:tidyup] = [:age, :size].collect { |param|
                @parameters[param]
            }.reject { |p| p == false }
        end

    end
end

# $Id$
