#--
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Bryan Kearney <bkearney@redhat.com>

require 'augeas' if Puppet.features.augeas?

Puppet::Type.type(:augeas).provide(:augeas) do
    include Puppet::Util

    confine :true => Puppet.features.augeas?

    has_features :parse_commands, :need_to_run?,:execute_changes

    SAVE_NOOP = "noop"
    SAVE_OVERWRITE = "overwrite"

    attr_accessor :aug

    # Extracts an 2 dimensional array of commands which are in the
    # form of command path value.
    # The input can be
    # - A string with one command
    # - A string with many commands per line
    # - An array of strings.
    def parse_commands(data)
        commands = Array.new()
        if data.is_a?(String)
            data.each_line do |line|
                cmd_array = Array.new()
                single = line.index("'")
                double = line.index('"')
                tokens = nil
                delim = " "
                if ((single != nil) or (double != nil))
                    single = 99999 if single == nil
                    double = 99999 if double == nil
                    delim = '"' if double < single
                    delim = "'" if single < double
                end
                tokens = line.split(delim)
                # If the length of tokens is 2, thn that means the pattern was
                # command file "some text", therefore we need to re-split
                # the first line
                if tokens.length == 2
                    tokens = (tokens[0].split(" ")) << tokens[1]
                end
                cmd = tokens.shift().strip()
                delim = "" if delim == " "
                file = tokens.shift().strip()
                other = tokens.join(" ").strip()
                cmd_array << cmd if !cmd.nil?
                cmd_array << file if !file.nil?
                cmd_array << other if other != ""
                commands << cmd_array
            end
        elsif data.is_a?(Array)
            data.each do |datum|
                commands.concat(parse_commands(datum))
            end
        end
        return commands
    end


    def open_augeas
        if (@aug.nil?)
            flags = 0
            (flags = 1 << 2 ) if self.resource[:type_check] == :true
            root = self.resource[:root]
            load_path = self.resource[:load_path]
            debug("Opening augeas with root #{root}, lens path #{load_path}, flags #{flags}")
            @aug = Augeas.open(root, load_path,flags)

            if (self.get_augeas_version() >= "0.3.6")
                debug("Augeas version #{self.get_augeas_version()} is installed")
            end
        end
        @aug
    end

    def close_augeas
        if (!@aug.nil?)
            @aug.close()
            debug("Closed the augeas connection")
            @aug = nil;
        end
    end

    # Used by the need_to_run? method to process get filters. Returns
    # true if there is a match, false if otherwise
    # Assumes a syntax of get /files/path [COMPARATOR] value
    def process_get(cmd_array)
        return_value = false

        #validate and tear apart the command
        fail ("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 4
        cmd = cmd_array.shift()
        path = cmd_array.shift()
        comparator = cmd_array.shift()
        arg = cmd_array.join(" ")

        #check the value in augeas
        result = @aug.get(path) || ''
        unless result.nil?
            case comparator
                when "!=":
                    return_value = true if !(result == arg)
                when "=~":
                    regex = Regexp.new(arg)
                    loc = result=~ regex
                    return_value = true if ! loc.nil?
                else
                    return_value = true if (result.send(comparator, arg))
            end
        end
        return_value
    end

    # Used by the need_to_run? method to process match filters. Returns
    # true if there is a match, false if otherwise
    def process_match(cmd_array)
        return_value = false

        #validate and tear apart the command
        fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 4
        cmd = cmd_array.shift()
        path = cmd_array.shift()
        verb = cmd_array.shift()

        #Get the values from augeas
        result = @aug.match(path) || ''
        # Now do the work
        unless (result.nil?)
            case verb
                when "size":
                    fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length != 2
                    comparator = cmd_array.shift()
                    arg = cmd_array.shift().to_i
                    return_value = true if (result.size.send(comparator, arg))
                when "include":
                    arg = cmd_array.join(" ")
                    return_value = true if result.include?(arg)
                when "==":
                    begin
                        arg = cmd_array.join(" ")
                        new_array = eval arg
                        return_value = true if result == new_array
                    rescue
                        fail("Invalid array in command: #{cmd_array.join(" ")}")
                    end
            end
        end
        return_value
    end

    def get_augeas_version
        return @aug.get("/augeas/version") || ""
    end

    def set_augeas_save_mode(mode)
        return @aug.set("/augeas/save", mode)
    end

    def files_changed?
        saved_files = @aug.match("/augeas/events/saved")
        return saved_files.size() > 0
    end

    # Determines if augeas acutally needs to run.
    def need_to_run?
        force = resource[:force]
        return_value = true
        self.open_augeas()
        filter = resource[:onlyif]
        unless (filter == "")
            cmd_array = filter.split
            command = cmd_array[0];
            cmd_array[1]= File.join(resource[:context], cmd_array[1])
            begin
                data = nil
                case command
                    when "get" then return_value = process_get(cmd_array)
                    when "match" then return_value = process_match(cmd_array)
                end
            rescue Exception => e
                fail("Error sending command '#{command}' with params #{cmd_array[1..-1].inspect}/#{e.message}")
            end
        end

        unless (force)
            # If we have a verison of augeas which is at least 0.3.6 then we
            # can make the changes now, see if changes were made, and
            # actually do the save.
            if ((return_value) and (self.get_augeas_version() >= "0.3.6"))
                debug("Will attempt to save and only run if files changed")
                self.set_augeas_save_mode(SAVE_NOOP)
                self.do_execute_changes()
                save_result = @aug.save()
                saved_files = @aug.match("/augeas/events/saved")
                if ((save_result) and (not files_changed?))
                    debug("Skipping becuase no files were changed")
                    return_value = false
                else
                    debug("Files changed, should execute")
                end
            end
        end
        self.close_augeas()
        return return_value
    end

    def execute_changes
        # Re-connect to augeas, and re-execute the changes
        self.open_augeas()
        if (self.get_augeas_version() >= "0.3.6")
            self.set_augeas_save_mode(SAVE_OVERWRITE)
        end

        self.do_execute_changes()

        success = @aug.save()
        if (success != true)
            fail("Save failed with return code #{success}")
        end
        self.close_augeas()

        return :executed
    end

    # Actually execute the augeas changes.
    def do_execute_changes
        commands = resource[:changes].clone()
        context = resource[:context]
        commands.each do |cmd_array|
            cmd_array = cmd_array.clone()
            fail("invalid command #{cmd_array.join[" "]}") if cmd_array.length < 2
            command = cmd_array[0]
            cmd_array.shift()
            begin
                case command
                    when "set":
                        cmd_array[0]=File.join(context, cmd_array[0])
                        debug("sending command '#{command}' with params #{cmd_array.inspect}")
                        @aug.set(cmd_array[0], cmd_array[1])
                    when "rm", "remove":
                        cmd_array[0]=File.join(context, cmd_array[0])
                        debug("sending command '#{command}' with params #{cmd_array.inspect}")
                        @aug.rm(cmd_array[0])
                    when "clear":
                        cmd_array[0]=File.join(context, cmd_array[0])
                        debug("sending command '#{command}' with params #{cmd_array.inspect}")
                        @aug.clear(cmd_array[0])
                    when "insert", "ins"
                        ext_array = cmd_array[1].split(" ") ;
                        if cmd_array.size < 2 or ext_array.size < 2
                            fail("ins requires 3 parameters")
                        end
                        label = cmd_array[0]
                        where = ext_array[0]
                        path = File.join(context, ext_array[1])
                        case where
                            when "before": before = true
                            when "after": before = false
                            else fail("Invalid value '#{where}' for where param")
                        end
                        debug("sending command '#{command}' with params #{[label, where, path].inspect()}")
                        aug.insert(path, label, before)
                    else fail("Command '#{command}' is not supported")
                end
            rescue Exception => e
                fail("Error sending command '#{command}' with params #{cmd_array.inspect}/#{e.message}")
            end
        end
    end

end
