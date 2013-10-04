module Puppet::Util::InlineDocs
  def self.included(klass)
    klass.send(:include, InstanceMethods)
    klass.extend ClassMethods
  end

  module ClassMethods
    attr_accessor :use_docs
    def associates_doc
      self.use_docs = true
    end
  end

  module InstanceMethods
    attr_writer :doc

    def doc
      @doc ||= ""
    end

    # don't fetch lexer comment by default
    def use_docs
      self.class.use_docs
    end
  end
end
