# Module Puppet::IniConfig
# A generic way to parse .ini style files and manipulate them in memory
# One 'file' can be made up of several physical files. Changes to sections
# on the file are tracked so that only the physical files in which
# something has changed are written back to disk
# Great care is taken to preserve comments and blank lines from the original
# files
#
# The parsing tries to stay close to python's ConfigParser

require 'puppet/util/filetype'

module Puppet::Util::IniConfig
    # A section in a .ini file
    class Section
        attr_reader :name, :file

        def initialize(name, file)
            @name = name
            @file = file
            @dirty = false
            @entries = []
        end

        # Has this section been modified since it's been read in
        # or written back to disk
        def dirty?
            @dirty
        end

        # Should only be used internally
        def mark_clean
            @dirty = false
        end

        # Add a line of text (e.g., a comment) Such lines
        # will be written back out in exactly the same
        # place they were read in
        def add_line(line)
            @entries << line
        end

        # Set the entry 'key=value'. If no entry with the
        # given key exists, one is appended to teh end of the section
        def []=(key, value)
            entry = find_entry(key)
            @dirty = true
            if entry.nil?
                @entries << [key, value]
            else
                entry[1] = value
            end
        end

        # Return the value associated with KEY. If no such entry
        # exists, return nil
        def [](key)
            entry = find_entry(key)
            if entry.nil?
                return nil
            end
            return entry[1]
        end

        # Format the section as text in the way it should be
        # written to file
        def format
            text = "[#{name}]\n"
            @entries.each do |entry|
                if entry.is_a?(Array)
                    key, value = entry
                    unless value.nil?
                        text << "#{key}=#{value}\n"
                    end
                else
                    text << entry
                end
            end
            return text
        end

        private
        def find_entry(key)
            @entries.each do |entry|
                if entry.is_a?(Array) && entry[0] == key
                    return entry
                end
            end
            return nil
        end

    end

    # A logical .ini-file that can be spread across several physical
    # files. For each physical file, call #read with the filename
    class File
        def initialize
            @files = {}
        end

        # Add the contents of the file with name FILE to the
        # already existing sections
        def read(file)
            text = Puppet::Util::FileType.filetype(:flat).new(file).read
            if text.nil?
                raise "Could not find #{file}"
            end

            section = nil   # The name of the current section
            optname = nil   # The name of the last option in section
            line = 0
            @files[file] = []
            text.each_line do |l|
                line += 1
                if l.strip.empty? || "#;".include?(l[0,1]) ||
                        (l.split(nil, 2)[0].downcase == "rem" &&
                         l[0,1].downcase == "r")
                    # Whitespace or comment
                    if section.nil?
                        @files[file] << l
                    else
                        section.add_line(l)
                    end
                elsif " \t\r\n\f".include?(l[0,1]) && section && optname
                    # continuation line
                    section[optname] += "\n" + l.chomp
                elsif l =~ /^\[([^\]]+)\]/
                    # section heading
                    section.mark_clean unless section.nil?
                    section = add_section($1, file)
                    optname = nil
                elsif l =~ /^\s*([^\s=]+)\s*\=(.*)$/
                    # We allow space around the keys, but not the values
                    # For the values, we don't know if space is significant
                    if section.nil?
                        raise "#{file}:#{line}:Key/value pair outside of a section for key #{$1}"
                    else
                        section[$1] = $2
                        optname = $1
                    end
                else
                    raise "#{file}:#{line}: Can't parse '#{l.chomp}'"
                end
            end
            section.mark_clean unless section.nil?
        end

        # Store all modifications made to sections in this file back
        # to the physical files. If no modifications were made to
        # a physical file, nothing is written
        def store
            @files.each do |file, lines|
                text = ""
                dirty = false
                lines.each do |l|
                    if l.is_a?(Section)
                        dirty ||= l.dirty?
                        text << l.format
                        l.mark_clean
                    else
                        text << l
                    end
                end
                if dirty
                    Puppet::Util::FileType.filetype(:flat).new(file).write(text)
                    return file
                end
            end
        end

        # Execute BLOCK, passing each section in this file
        # as an argument
        def each_section(&block)
            @files.each do |file, list|
                list.each do |entry|
                    if entry.is_a?(Section)
                        yield(entry)
                    end
                end
            end
        end

        # Execute BLOCK, passing each file constituting this inifile
        # as an argument
        def each_file(&block)
            @files.keys.each do |file|
                yield(file)
            end
        end

        # Return the Section with the given name or nil
        def [](name)
            name = name.to_s
            each_section do |section|
                return section if section.name == name
            end
            return nil
        end

        # Return true if the file contains a section with name NAME
        def include?(name)
            return ! self[name].nil?
        end

        # Add a section to be stored in FILE when store is called
        def add_section(name, file)
            if include?(name)
                raise "A section with name #{name} already exists"
            end
            result = Section.new(name, file)
            @files[file] ||= []
            @files[file] << result
            return result
        end
    end
end

