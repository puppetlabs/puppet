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
#class Puppet::Provider::Augeas < Puppet::Provider
    include Puppet::Util
    
    confine :true => Puppet.features.augeas?   
    
    has_features :parse_commands, :need_to_run?,:execute_changes

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
                tokens = line.split(" ")
                cmd = tokens.shift()
                file = tokens.shift()
                other = tokens.join(" ")
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
        flags = 0
        (flags = 1 << 2 ) if self.resource[:type_check] == :true
        root = self.resource[:root]
        load_path = self.resource[:load_path]
        debug("Opening augeas with root #{root}, lens path #{load_path}, flags #{flags}")
        Augeas.open(root, load_path,flags)
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
        aug = open_augeas()
        result = aug.get(path) || ''
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
        aug = open_augeas()
        result = aug.match(path) || ''
        # Now do the work
        if (!result.nil?)
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
    
    # Determines if augeas acutally needs to run.
    def need_to_run?
        return_value = true
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
        return_value
    end 
    
    # Actually execute the augeas changes.
    def execute_changes
        aug = open_augeas
        commands = resource[:changes]
        context = resource[:context]
        commands.each do |cmd_array|
            fail("invalid command #{cmd_array.join[" "]}") if cmd_array.length < 2
            command = cmd_array[0]
            cmd_array.shift()
            cmd_array[0]=File.join(context, cmd_array[0])
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            begin
                case command
                    when "set": aug.set(cmd_array[0], cmd_array[1])
                    when "rm", "remove": aug.rm(cmd_array[0])
                    when "clear": aug.clear(cmd_array[0])
                    when "insert", "ins": aug.insert(cmd_array[0])
                    else fail("Command '#{command}' is not supported")
                end
            rescue Exception => e
                fail("Error sending command '#{command}' with params #{cmd_array.inspect}/#{e.message}")
            end
        end
        success = aug.save()
        if (success != true)
            fail("Save failed with return code #{success}")
        end

        return :executed    
    end   
    
end
