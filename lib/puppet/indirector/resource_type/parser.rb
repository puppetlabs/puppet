require 'puppet/resource/type'
require 'puppet/indirector/code'
require 'puppet/indirector/resource_type'

class Puppet::Indirector::ResourceType::Parser < Puppet::Indirector::Code
  desc "Return the data-form of a resource type."

  def find(request)
    krt = request.environment.known_resource_types

    # This is a bit ugly.
    [:hostclass, :definition, :node].each do |type|
      # We have to us 'find_<type>' here because it will
      # load any missing types from disk, whereas the plain
      # '<type>' method only returns from memory.
      if r = krt.send("find_#{type}", [""], request.key)
        return r
      end
    end
    nil
  end

  # This is the "search" indirection method for resource types.  It searches
  #  through a specified environment for all custom declared classes
  #  (a.k.a 'hostclasses'), defined types (a.k.a. 'definitions'), and nodes.
  #
  # @param [Puppet::Indirector::Request] request
  #   Important properties of the request parameter:
  #   1. request.environment : The environment in which to look for types.
  #   2. request.key : A String that will be treated as a regular expression to
  #         be matched against the names of the available types.  You may also
  #         pass a "*", which will match all available types.
  #   3. request.options[:kind] : a String that can be used to filter the output
  #         to only return the desired kinds.  The current supported values are
  #         'class', 'defined_type', and 'node'.
  def search(request)
    krt = request.environment.known_resource_types
    # Make sure we've got all of the types loaded.
    krt.loader.import_all

    result_candidates = case request.options[:kind]
        when "class"
          krt.hostclasses.values
        when "defined_type"
          krt.definitions.values
        when "node"
          krt.nodes.values
        when nil
          result_candidates = [krt.hostclasses.values, krt.definitions.values, krt.nodes.values]
        else
          raise ArgumentError, "Unrecognized kind filter: " +
                    "'#{request.options[:kind]}', expected one " +
                    " of 'class', 'defined_type', or 'node'."
      end

    result = result_candidates.flatten.reject { |t| t.name == "" }
    return nil if result.empty?
    return result if request.key == "*"

    # Strip the regex of any wrapping slashes that might exist
    key = request.key.sub(/^\//, '').sub(/\/$/, '')
    begin
      regex = Regexp.new(key)
    rescue => detail
      raise ArgumentError, "Invalid regex '#{request.key}': #{detail}"
    end

    result.reject! { |t| t.name.to_s !~ regex }
    return nil if result.empty?
    result
  end
end
