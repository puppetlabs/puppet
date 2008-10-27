#--
#  Copyright (C) 2008 Red Hat Inc.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  Lesser General Public License for more details.
#
#  You should have received a copy of the GNU Lesser General Public
#  License along with this library; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307  USA
#
# Author: Bryan Kearney <bkearney@redhat.com>

require 'augeas' if Puppet.features.augeas?

Puppet::Type.type(:augeas).provide(:augeas) do
#class Puppet::Provider::Augeas < Puppet::Provider
    include Puppet::Util
    
    confine "The augeas Ruby bindings are not available" => Puppet.features.augeas?    


    # Extracts an 2 dimensional array of commands which are in the
    # form of command path value.
    # The input can be
    # - A string with one command
    # - A string with many commands per line
    # - An array of strings.
    self.def parse_commands(data)
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
        
    # This is the acutal meat of the code. It forces
    # augeas to be run and fails or not based on the augeas return
    # code.
    newproperty(:returns) do |property|
        include Puppet::Util
        desc "The expected return code from the augeas command. Should not be set"

        defaultto 0

        def open_augeas
            flags = 0
            (flags = 1 << 2 ) if self.resource[:type_check] == :true
            root = self.resource[:root]
            load_path = self.resource[:load_path]
            debug("Opening augeas with root #{root}, lens path #{load_path}, flags #{flags}")
            Augeas.open(root, load_path,flags)
        end

        # Make output a bit prettier
        def change_to_s(currentvalue, newvalue)
            return "executed successfully"
        end

        # method to handle the onlif get strings.
        # Assumes a syntax of get /files/path [COMPARATOR] value
        def process_get(cmd_array)
            return_value = 0

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
            			return_value = :need_to_run if !(result == arg)
            		when "=~":
            			regex = Regexp.new(arg)
            			loc = result=~ regex
            			return_value = :need_to_run if ! loc.nil?
            		else
            			return_value = :need_to_run if (result.send(comparator, arg))
                end
            end
            return_value
        end

        # This will handle the following cases
        def process_match(cmd_array)
            return_value = 0

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
                        return_value = :need_to_run if (result.size.send(comparator, arg))
                    when "include":
                        arg = cmd_array.join(" ")
                        return_value = :need_to_run if result.include?(arg)
                    when "==":
                        begin
                            arg = cmd_array.join(" ")
                            new_array = eval arg
                            return_value = :need_to_run if result == new_array
                        rescue
                            fail("Invalid array in command: #{cmd_array.join(" ")}")
                        end
                end
            end
            return_value
        end

        # if the onlyif resource is provided, then the value is parsed.
        # a return value of 0 will stop exection becuase it matches the
        # default value.
        def retrieve
            return_value = :need_to_run
            filter = self.resource[:onlyif]
            unless (filter == "")
                cmd_array = filter.split
                command = cmd_array[0];
                cmd_array[1]= File.join(resource[:context], cmd_array[1])
                begin
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

        # Actually execute the command.
        def sync
            aug = open_augeas
            commands = self.resource[:changes]
            commands.each do |cmd_array|
                fail("invalid command #{cmd_array.join[" "]}") if cmd_array.length < 2
                command = cmd_array[0]
                cmd_array.shift()
                cmd_array[0]=File.join(resource[:context], cmd_array[0])
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
end
