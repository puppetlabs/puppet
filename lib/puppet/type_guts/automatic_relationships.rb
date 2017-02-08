# -*- coding: utf-8 -*-

module Puppet
  class Type
    # Adds a block producing a single name (or list of names) of the given
    # resource type name to autorelate.
    #
    # The four relationship types require, before, notify, and subscribe are all
    # supported.
    #
    # Be *careful* with notify and subscribe as they may have unintended
    # consequences.
    #
    # Resources in the catalog that have the named type and a title that is
    # included in the result will be linked to the calling resource as a
    # requirement.
    #
    # @example Autorequire the files File['foo', 'bar']
    #   autorequire( 'file', {|| ['foo', 'bar'] })
    #
    # @example Autobefore the files File['foo', 'bar']
    #   autobefore( 'file', {|| ['foo', 'bar'] })
    #
    # @example Autosubscribe the files File['foo', 'bar']
    #   autosubscribe( 'file', {|| ['foo', 'bar'] })
    #
    # @example Autonotify the files File['foo', 'bar']
    #   autonotify( 'file', {|| ['foo', 'bar'] })
    #
    # @param name [String] the name of a type of which one or several resources should be autorelated e.g. "file"
    # @yield [ ] a block returning list of names of given type to auto require
    # @yieldreturn [String, Array<String>] one or several resource names for the named type
    # @return [void]
    # @dsl type
    # @api public
    #
    def self.autorequire(name, &block)
      @autorequires ||= {}
      @autorequires[name] = block
    end

    def self.autobefore(name, &block)
      @autobefores ||= {}
      @autobefores[name] = block
    end

    def self.autosubscribe(name, &block)
      @autosubscribes ||= {}
      @autosubscribes[name] = block
    end

    def self.autonotify(name, &block)
      @autonotifies ||= {}
      @autonotifies[name] = block
    end

    # Provides iteration over added auto-requirements (see {autorequire}).
    # @yieldparam type [String] the name of the type to autorequire an instance of
    # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autorequire}).
    # @yieldreturn [void]
    # @return [void]
    def self.eachautorequire
      @autorequires ||= {}
      @autorequires.each { |type, block|
        yield(type, block)
      }
    end

    # Provides iteration over added auto-requirements (see {autobefore}).
    # @yieldparam type [String] the name of the type to autorequire an instance of
    # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autobefore}).
    # @yieldreturn [void]
    # @return [void]
    def self.eachautobefore
      @autobefores ||= {}
      @autobefores.each { |type,block|
        yield(type, block)
      }
    end

    # Provides iteration over added auto-requirements (see {autosubscribe}).
    # @yieldparam type [String] the name of the type to autorequire an instance of
    # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autosubscribe}).
    # @yieldreturn [void]
    # @return [void]
    def self.eachautosubscribe
      @autosubscribes ||= {}
      @autosubscribes.each { |type,block|
        yield(type, block)
      }
    end

    # Provides iteration over added auto-requirements (see {autonotify}).
    # @yieldparam type [String] the name of the type to autorequire an instance of
    # @yieldparam block [Proc] a block producing one or several dependencies to auto require (see {autonotify}).
    # @yieldreturn [void]
    # @return [void]
    def self.eachautonotify
      @autonotifies ||= {}
      @autonotifies.each { |type,block|
        yield(type, block)
      }
    end

    # Adds dependencies to the catalog from added autorelations.
    # See {autorequire} for how to add an auto-requirement.
    # @todo needs details - see the param rel_catalog, and type of this param
    # @param rel_catalog [Puppet::Resource::Catalog, nil] the catalog to
    #   add dependencies to. Defaults to the current catalog (set when the
    #   type instance was added to a catalog)
    # @raise [Puppet::DevError] if there is no catalog
    #
    def autorelation(rel_type, rel_catalog = nil)
      rel_catalog ||= catalog
      raise(Puppet::DevError, "You cannot add relationships without a catalog") unless rel_catalog

      reqs = []

      auto_rel = "eachauto#{rel_type}".to_sym

      self.class.send(auto_rel) { |type, block|
        # Ignore any types we can't find, although that would be a bit odd.
        next unless Puppet::Type.type(type)

        # Retrieve the list of names from the block.
        next unless list = self.instance_eval(&block)
        list = [list] unless list.is_a?(Array)

        # Collect the current prereqs
        list.each { |dep|
          next if dep.nil?

          # Support them passing objects directly, to save some effort.
          unless dep.is_a?(Puppet::Type)
            # Skip autorelation that we aren't managing
            unless dep = rel_catalog.resource(type, dep)
              next
            end
          end

          if [:require, :subscribe].include?(rel_type)
            reqs << Puppet::Relationship.new(dep, self)
          else
            reqs << Puppet::Relationship.new(self, dep)
          end
        }
      }

      reqs
    end

    def autorequire(rel_catalog = nil)
      autorelation(:require, rel_catalog)
    end

    def autobefore(rel_catalog = nil)
      autorelation(:before, rel_catalog)
    end

    def autosubscribe(rel_catalog = nil)
      autorelation(:subscribe, rel_catalog)
    end

    def autonotify(rel_catalog = nil)
      autorelation(:notify, rel_catalog)
    end

    # Builds the dependencies associated with this resource.
    #
    # @return [Array<Puppet::Relationship>] list of relationships to other resources
    def builddepends
      # Handle the requires
      self.class.relationship_params.collect do |klass|
        if param = @parameters[klass.name]
          param.to_edges
        end
      end.flatten.reject { |r| r.nil? }
    end
  end
end
