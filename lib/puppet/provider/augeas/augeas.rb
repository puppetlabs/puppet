#
#   Copyright 2011 Bryan Kearney <bkearney@redhat.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       https://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

require 'augeas' if Puppet.features.augeas?
require 'strscan'
require 'puppet/util'
require 'puppet/util/diff'
require 'puppet/util/package'

Puppet::Type.type(:augeas).provide(:augeas) do
  include Puppet::Util
  include Puppet::Util::Diff
  include Puppet::Util::Package

  confine :feature => :augeas

  has_features :parse_commands, :need_to_run?,:execute_changes

  SAVE_NOOP = "noop"
  SAVE_OVERWRITE = "overwrite"
  SAVE_NEWFILE = "newfile"
  SAVE_BACKUP = "backup"

  COMMANDS = {
    "set" => [ :path, :string ],
    "setm" => [ :path, :string, :string ],
    "rm" => [ :path ],
    "clear" => [ :path ],
    "clearm" => [ :path, :string ],
    "touch" => [ :path ],
    "mv" => [ :path, :path ],
    "rename" => [ :path, :string ],
    "insert" => [ :string, :string, :path ],
    "get" => [ :path, :comparator, :string ],
    "values" => [ :path, :glob ],
    "defvar" => [ :string, :path ],
    "defnode" => [ :string, :path, :string ],
    "match" => [ :path, :glob ],
    "size" => [:comparator, :int],
    "include" => [:string],
    "not_include" => [:string],
    "==" => [:glob],
    "!=" => [:glob]
  }

  COMMANDS["ins"] = COMMANDS["insert"]
  COMMANDS["remove"] = COMMANDS["rm"]
  COMMANDS["move"] = COMMANDS["mv"]

  attr_accessor :aug

  # Extracts an 2 dimensional array of commands which are in the
  # form of command path value.
  # The input can be
  # - A string with one command
  # - A string with many commands per line
  # - An array of strings.
  def parse_commands(data)
    context = resource[:context]
    # Add a trailing / if it is not there
    if (context.length > 0)
      context << "/" if context[-1, 1] != "/"
    end

    data = data.split($/) if data.is_a?(String)
    data = data.flatten
    args = []
    data.each do |line|
      line.strip!
      next if line.nil? || line.empty?
      argline = []
      sc = StringScanner.new(line)
      cmd = sc.scan(/\w+|==|!=/)
      formals = COMMANDS[cmd]
      fail("Unknown command #{cmd}") unless formals
      argline << cmd
      narg = 0
      formals.each do |f|
        sc.skip(/\s+/)
        narg += 1
        if f == :path
          start = sc.pos
          nbracket = 0
          inSingleTick = false
          inDoubleTick = false
          begin
            sc.skip(/([^\]\[\s\\'"]|\\.)+/)
            ch = sc.getch
            nbracket += 1 if ch == "["
            nbracket -= 1 if ch == "]"
            inSingleTick = !inSingleTick if ch == "'"
            inDoubleTick = !inDoubleTick if ch == "\""
            fail("unmatched [") if nbracket < 0
          end until ((nbracket == 0 && !inSingleTick && !inDoubleTick && (ch =~ /\s/)) || sc.eos?)
            len = sc.pos - start
            len -= 1 unless sc.eos?
          unless p = sc.string[start, len]
            fail("missing path argument #{narg} for #{cmd}")
          end
          # Rip off any ticks if they are there.
          p = p[1, (p.size - 2)] if p[0,1] == "'" || p[0,1] == "\""
          p.chomp!("/")
          if p[0,1] != '$' && p[0,1] != "/"
            argline << context + p
          else
            argline << p
          end
        elsif f == :string
          delim = sc.peek(1)
          if delim == "'" || delim == "\""
            sc.getch
            argline << sc.scan(/([^\\#{delim}]|(\\.))*/)
            sc.getch
          else
            argline << sc.scan(/[^\s]+/)
          end
          fail("missing string argument #{narg} for #{cmd}") unless argline[-1]
        elsif f == :comparator
          argline << sc.scan(/(==|!=|=~|<=|>=|<|>)/)
          unless argline[-1]
            puts sc.rest
            fail("invalid comparator for command #{cmd}")
          end
        elsif f == :int
          argline << sc.scan(/\d+/).to_i
        elsif f== :glob
          argline << sc.rest
        end
      end
      args << argline
    end
    args
  end


  def open_augeas
    unless @aug
      flags = Augeas::NONE
      flags = Augeas::TYPE_CHECK if resource[:type_check] == :true

      if resource[:incl]
        flags |= Augeas::NO_MODL_AUTOLOAD
      else
        flags |= Augeas::NO_LOAD
      end

      root = resource[:root]
      load_path = get_load_path(resource)
      debug("Opening augeas with root #{root}, lens path #{load_path}, flags #{flags}")
      @aug = Augeas::open(root, load_path,flags)

      debug("Augeas version #{get_augeas_version} is installed") if versioncmp(get_augeas_version, "0.3.6") >= 0

      # Optimize loading if the context is given and it's a simple path,
      # requires the glob function from Augeas 0.8.2 or up
      glob_avail = !aug.match("/augeas/version/pathx/functions/glob").empty?
      opt_ctx = resource[:context].match("^/files/[^'\"\\[\\]]+$") if resource[:context]

      restricted = false
      if resource[:incl]
        aug.set("/augeas/load/Xfm/lens", resource[:lens])
        aug.set("/augeas/load/Xfm/incl", resource[:incl])
        restricted_metadata = "/augeas//error"
      elsif glob_avail and opt_ctx
        # Optimize loading if the context is given, requires the glob function
        # from Augeas 0.8.2 or up
        ctx_path = resource[:context].sub(/^\/files(.*?)\/?$/, '\1/')
        load_path = "/augeas/load/*['%s' !~ glob(incl) + regexp('/.*')]" % ctx_path

        if aug.match(load_path).size < aug.match("/augeas/load/*").size
          aug.rm(load_path)
          restricted_metadata = "/augeas/files#{ctx_path}/error"
        else
          # This will occur if the context is less specific than any glob
          debug("Unable to optimize files loaded by context path, no glob matches")
        end
      end
      aug.load
      print_load_errors(restricted_metadata)
    end
    @aug
  end

  def close_augeas
    if @aug
      @aug.close
      debug("Closed the augeas connection")
      @aug = nil
    end
  end

  def is_numeric?(s)
    case s
    when Fixnum
      true
    when String
      s.match(/\A[+-]?\d+?(\.\d+)?\Z/n) == nil ? false : true
    else
      false
    end
  end

  # Used by the need_to_run? method to process get filters. Returns
  # true if there is a match, false if otherwise
  # Assumes a syntax of get /files/path [COMPARATOR] value
  def process_get(cmd_array)
    return_value = false

    #validate and tear apart the command
    fail ("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 4
    cmd = cmd_array.shift
    path = cmd_array.shift
    comparator = cmd_array.shift
    arg = cmd_array.join(" ")

    #check the value in augeas
    result = @aug.get(path) || ''

    if ['<', '<=', '>=', '>'].include? comparator and is_numeric?(result) and
                                                      is_numeric?(arg)
      resultf = result.to_f
      argf = arg.to_f
      return_value = (resultf.send(comparator, argf))
    elsif comparator == "!="
      return_value = (result != arg)
    elsif comparator == "=~"
      regex = Regexp.new(arg)
      return_value = (result =~ regex)
    else
      return_value = (result.send(comparator, arg))
    end
    !!return_value
  end

  # Used by the need_to_run? method to process values filters. Returns
  # true if there is a matched value, false if otherwise
  def process_values(cmd_array)
    return_value = false

    #validate and tear apart the command
    fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 3
    cmd = cmd_array.shift
    path = cmd_array.shift

    # Need to break apart the clause
    clause_array = parse_commands(cmd_array.shift)[0]
    verb = clause_array.shift

    #Get the match paths from augeas
    result = @aug.match(path) || []
    fail("Error trying to get path '#{path}'") if (result == -1)

    #Get the values of the match paths from augeas
    values = result.collect{|r| @aug.get(r)}

    case verb
    when "include"
      arg = clause_array.shift
      return_value = values.include?(arg)
    when "not_include"
      arg = clause_array.shift
      return_value = !values.include?(arg)
    when "=="
      begin
        arg = clause_array.shift
        new_array = eval arg
        return_value = (values == new_array)
      rescue
        fail("Invalid array in command: #{cmd_array.join(" ")}")
      end
    when "!="
      begin
        arg = clause_array.shift
        new_array = eval arg
        return_value = (values != new_array)
      rescue
        fail("Invalid array in command: #{cmd_array.join(" ")}")
      end
    end
    !!return_value
  end

  # Used by the need_to_run? method to process match filters. Returns
  # true if there is a match, false if otherwise
  def process_match(cmd_array)
    return_value = false

    #validate and tear apart the command
    fail("Invalid command: #{cmd_array.join(" ")}") if cmd_array.length < 3
    cmd = cmd_array.shift
    path = cmd_array.shift

    # Need to break apart the clause
    clause_array = parse_commands(cmd_array.shift)[0]
    verb = clause_array.shift

    #Get the values from augeas
    result = @aug.match(path) || []
    fail("Error trying to match path '#{path}'") if (result == -1)

    # Now do the work
    case verb
    when "size"
      fail("Invalid command: #{cmd_array.join(" ")}") if clause_array.length != 2
      comparator = clause_array.shift
      arg = clause_array.shift
      case comparator
      when "!="
        return_value = !(result.size.send(:==, arg))
      else
        return_value = (result.size.send(comparator, arg))
      end
    when "include"
      arg = clause_array.shift
      return_value = result.include?(arg)
    when "not_include"
      arg = clause_array.shift
      return_value = !result.include?(arg)
    when "=="
      begin
        arg = clause_array.shift
        new_array = eval arg
        return_value = (result == new_array)
      rescue
        fail("Invalid array in command: #{cmd_array.join(" ")}")
      end
    when "!="
      begin
        arg = clause_array.shift
        new_array = eval arg
        return_value = (result != new_array)
      rescue
        fail("Invalid array in command: #{cmd_array.join(" ")}")
      end
    end
    !!return_value
  end

  # Generate lens load paths from user given paths and local pluginsync dir
  def get_load_path(resource)
    load_path = []

    # Permits colon separated strings or arrays
    if resource[:load_path]
      load_path = [resource[:load_path]].flatten
      load_path.map! { |path| path.split(/:/) }
      load_path.flatten!
    end

    if Puppet::FileSystem.exist?("#{Puppet[:libdir]}/augeas/lenses")
      load_path << "#{Puppet[:libdir]}/augeas/lenses"
    end

    load_path.join(":")
  end

  def get_augeas_version
    @aug.get("/augeas/version") || ""
  end

  def set_augeas_save_mode(mode)
    @aug.set("/augeas/save", mode)
  end

  def print_load_errors(path)
    errors = @aug.match("/augeas//error")
    unless errors.empty?
      if path && !@aug.match(path).empty?
        warning("Loading failed for one or more files, see debug for /augeas//error output")
      else
        debug("Loading failed for one or more files, output from /augeas//error:")
      end
    end
    print_errors(errors)
  end

  def print_put_errors
    errors = @aug.match("/augeas//error[. = 'put_failed']")
    debug("Put failed on one or more files, output from /augeas//error:") unless errors.empty?
    print_errors(errors)
  end

  def print_errors(errors)
    errors.each do |errnode|
      error = @aug.get(errnode)
      debug("#{errnode} = #{error}") unless error.nil?
      @aug.match("#{errnode}/*").each do |subnode|
        subvalue = @aug.get(subnode)
        debug("#{subnode} = #{subvalue}")
      end
    end
  end

  # Determines if augeas actually needs to run.
  def need_to_run?
    force = resource[:force]
    return_value = true
    begin
      open_augeas
      filter = resource[:onlyif]
      unless filter == ""
        cmd_array = parse_commands(filter)[0]
        command = cmd_array[0];
        begin
          case command
          when "get"; return_value = process_get(cmd_array)
          when "values"; return_value = process_values(cmd_array)
          when "match"; return_value = process_match(cmd_array)
          end
        rescue StandardError => e
          fail("Error sending command '#{command}' with params #{cmd_array[1..-1].inspect}/#{e.message}")
        end
      end

      unless force
        # If we have a version of augeas which is at least 0.3.6 then we
        # can make the changes now and see if changes were made.
        if return_value and versioncmp(get_augeas_version, "0.3.6") >= 0
          debug("Will attempt to save and only run if files changed")
          # Execute in NEWFILE mode so we can show a diff
          set_augeas_save_mode(SAVE_NEWFILE)
          do_execute_changes
          save_result = @aug.save
          unless save_result
            print_put_errors
            fail("Saving failed, see debug")
          end

          saved_files = @aug.match("/augeas/events/saved")
          if saved_files.size > 0
            root = resource[:root].sub(/^\/$/, "")
            saved_files.map! {|key| @aug.get(key).sub(/^\/files/, root) }
            saved_files.uniq.each do |saved_file|
              if Puppet[:show_diff] && @resource[:show_diff]
                self.send(@resource[:loglevel], "\n" + diff(saved_file, saved_file + ".augnew"))
              end
              File.delete(saved_file + ".augnew")
            end
            debug("Files changed, should execute")
            return_value = true
          else
            debug("Skipping because no files were changed")
            return_value = false
          end
        end
      end
    ensure
      if not return_value or resource.noop? or not save_result
        close_augeas
      end
    end
    return_value
  end

  def execute_changes
    # Workaround Augeas bug where changing the save mode doesn't trigger a
    # reload of the previously saved file(s) when we call Augeas#load
    @aug.match("/augeas/events/saved").each do |file|
      @aug.rm("/augeas#{@aug.get(file)}/mtime")
    end

    # Reload augeas, and execute the changes for real
    set_augeas_save_mode(SAVE_OVERWRITE) if versioncmp(get_augeas_version, "0.3.6") >= 0
    @aug.load
    do_execute_changes
    unless @aug.save
      print_put_errors
      fail("Save failed, see debug")
    end

    :executed
  ensure
    close_augeas
  end

  # Actually execute the augeas changes.
  def do_execute_changes
    commands = parse_commands(resource[:changes])
    commands.each do |cmd_array|
      fail("invalid command #{cmd_array.join[" "]}") if cmd_array.length < 2
      command = cmd_array[0]
      cmd_array.shift
      begin
        case command
          when "set"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.set(cmd_array[0], cmd_array[1])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
          when "setm"
            if aug.respond_to?(command)
              debug("sending command '#{command}' with params #{cmd_array.inspect}")
              rv = aug.setm(cmd_array[0], cmd_array[1], cmd_array[2])
              fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (rv == -1)
            else
              fail("command '#{command}' not supported in installed version of ruby-augeas")
            end
          when "rm", "remove"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.rm(cmd_array[0])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (rv == -1)
          when "clear"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.clear(cmd_array[0])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
          when "clearm"
            # Check command exists ... doesn't currently in ruby-augeas 0.4.1
            if aug.respond_to?(command)
              debug("sending command '#{command}' with params #{cmd_array.inspect}")
              rv = aug.clearm(cmd_array[0], cmd_array[1])
              fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
            else
              fail("command '#{command}' not supported in installed version of ruby-augeas")
            end
          when "touch"
            debug("sending command '#{command}' (match, set) with params #{cmd_array.inspect}")
            if aug.match(cmd_array[0]).empty?
              rv = aug.clear(cmd_array[0])
              fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
            end
          when "insert", "ins"
            label = cmd_array[0]
            where = cmd_array[1]
            path = cmd_array[2]
            case where
              when "before"; before = true
              when "after"; before = false
              else fail("Invalid value '#{where}' for where param")
            end
            debug("sending command '#{command}' with params #{[label, where, path].inspect}")
            rv = aug.insert(path, label, before)
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (rv == -1)
          when "defvar"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.defvar(cmd_array[0], cmd_array[1])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
          when "defnode"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.defnode(cmd_array[0], cmd_array[1], cmd_array[2])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (!rv)
          when "mv", "move"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.mv(cmd_array[0], cmd_array[1])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (rv == -1)
          when "rename"
            debug("sending command '#{command}' with params #{cmd_array.inspect}")
            rv = aug.rename(cmd_array[0], cmd_array[1])
            fail("Error sending command '#{command}' with params #{cmd_array.inspect}") if (rv == -1)
          else fail("Command '#{command}' is not supported")
        end
      rescue StandardError => e
        fail("Error sending command '#{command}' with params #{cmd_array.inspect}/#{e.message}")
      end
    end
  end
end
