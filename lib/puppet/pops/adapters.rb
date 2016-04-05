# The Adapters module contains adapters for Documentation, Origin, SourcePosition, and Loader.
#
module Puppet::Pops
module Adapters
  # A documentation adapter adapts an object with a documentation string.
  # (The intended use is for a source text parser to extract documentation and store this
  # in DocumentationAdapter instances).
  #
  class DocumentationAdapter < Adaptable::Adapter
    # @return [String] The documentation associated with an object
    attr_accessor :documentation
  end

  # A SourcePosAdapter holds a reference to  a *Positioned* object (object that has offset and length).
  # This somewhat complex structure makes it possible to correctly refer to a source position
  # in source that is embedded in some resource; a parser only sees the embedded snippet of source text
  # and does not know where it was embedded. It also enables lazy evaluation of source positions (they are
  # rarely needed - typically just when there is an error to report.
  #
  # @note It is relatively expensive to compute line and position on line - it is not something that
  #   should be done for every token or model object.
  #
  # @see Utils#find_adapter, Utils#find_closest_positioned
  #
  class SourcePosAdapter < Adaptable::Adapter
    attr_accessor :locator
    attr_reader :adapted

    def self.create_adapter(o)
      new(o)
    end

    def initialize(o)
      @adapted = o
    end

    def locator
      # The locator is always the parent locator, all positioned objects are positioned within their
      # parent. If a positioned object also has a locator that locator is for its children!
      #
      @locator ||= find_locator(@adapted.eContainer)
    end

    def find_locator(o)
      if o.nil?
        raise ArgumentError, "InternalError: SourcePosAdapter for something that has no locator among parents"
      end
      case
      when o.is_a?(Model::Program)
        return o.locator
      # TODO_HEREDOC use case of SubLocator instead
      when o.is_a?(Model::SubLocatedExpression) && !(found_locator = o.locator).nil?
        return found_locator
      when adapter = self.class.get(o)
        return adapter.locator
      else
        find_locator(o.eContainer)
      end
    end
    private :find_locator

    def offset
      @adapted.offset
    end

    def length
      @adapted.length
    end

    # Produces the line number for the given offset.
    # @note This is an expensive operation
    #
    def line
      # Optimization: manual inlining of locator accessor since this method is frequently called
      (@locator ||= find_locator(@adapted.eContainer)).line_for_offset(offset)
    end

    # Produces the position on the line of the given offset.
    # @note This is an expensive operation
    #
    def pos
      locator.pos_on_line(offset)
    end

    # Extracts the text represented by this source position (the string is obtained from the locator)
    def extract_text
      locator.extract_text(offset, length)
    end

    def extract_tree_text
      first = @adapted.offset
      last = first + @adapted.length
      @adapted.eAllContents.each do |m|
        m_offset = m.offset
        next if m_offset.nil?
        first = m_offset if m_offset < first
        m_last = m_offset + m.length
        last = m_last if m_last > last
      end
      locator.extract_text(first, last-first)
    end

    # Produces an URI with path?line=n&pos=n. If origin is unknown the URI is string:?line=n&pos=n
    def to_uri
      f = locator.file
      if f.nil? || f.empty?
        f = 'string:'
      else
        f = Puppet::Util.path_to_uri(f).to_s
      end
      URI("#{f}?line=#{line.to_s}&pos=#{pos.to_s}")
    end
  end

  # A LoaderAdapter adapts an object with a {Loader}. This is used to make further loading from the
  # perspective of the adapted object take place in the perspective of this Loader.
  #
  # It is typically enough to adapt the root of a model as a search is made towards the root of the model
  # until a loader is found, but there is no harm in duplicating this information provided a contained
  # object is adapted with the correct loader.
  #
  # @see Utils#find_adapter
  #
  class LoaderAdapter < Adaptable::Adapter
    # @return [Loader::Loader] the loader
    attr_accessor :loader

    # Finds the loader to use when loading originates from the source position of the given argument.
    #
    # @param instance [Model::PopsObject] The model object
    # @param scope [Puppet::Parser::Scope] The scope to use
    # @return [Loader,nil] the found loader or `nil` if it could not be found
    #
    def self.loader_for_model_object(model, scope)
      # find the loader that loaded the code, or use the private_environment_loader (sees env + all modules)
      adapter = Utils.find_adapter(model, self)
      return adapter.loader unless adapter.nil?

      if scope.nil?
        loaders = Puppet.lookup(:loaders) { nil }
        loaders.nil? ? nil : loaders.private_environment_loader
      else
        # Use source location to determine calling module, or use the private_environment_loader (sees env + all modules)
        # This is necessary since not all .pp files are loaded by a Loader (see PUP-1833)
        adapter = adapt_by_source(scope, model)
        adapter.nil? ? scope.compiler.loaders.private_environment_loader : adapter.loader
      end
    end

    # Attempts to find the module that `instance` originates from by looking at it's {SourcePosAdapter} and
    # compare the `locator.file` found there with the module paths given in the environment found in the
    # given `scope`. If the file is found to be relative to a path, then the first segment of the relative
    # path is interpreted as the name of a module. The object that the {SourcePosAdapter} is adapted to
    # will then be adapted to the private loader for that module and that adapter is returned.
    #
    # The method returns `nil` when no module could be found.
    #
    # @param scope
    # @param instance
    def self.adapt_by_source(scope, instance)
      source_pos = Utils.find_adapter(instance, SourcePosAdapter)
      unless source_pos.nil?
        mod = find_module_for_file(scope.environment, source_pos.locator.file)
        unless mod.nil?
          adapter = LoaderAdapter.adapt(source_pos.adapted)
          adapter.loader = scope.compiler.loaders.private_loader_for_module(mod.name)
          return adapter
        end
      end
      nil
    end

    def self.find_module_for_file(environment, file)
      return nil if file.nil?
      file_path = Pathname.new(file)
      environment.modulepath.each do |path|
        begin
          relative_path = file_path.relative_path_from(Pathname.new(path)).to_s.split(File::SEPARATOR)
        rescue ArgumentError
          # file_path was not relative to the module_path. That's OK.
          next
        end
        if relative_path.length > 1
          mod = environment.module(relative_path[0])
          return mod unless mod.nil?
        end
      end
      nil
    end
    private_class_method :find_module_for_file
  end
end
end
