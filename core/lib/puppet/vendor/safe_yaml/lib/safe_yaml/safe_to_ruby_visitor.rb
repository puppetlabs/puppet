module SafeYAML
  class SafeToRubyVisitor < Psych::Visitors::ToRuby
    def initialize(resolver)
      super()
      @resolver = resolver
    end

    def accept(node)
      if node.tag
        SafeYAML.tag_safety_check!(node.tag, @resolver.options)
        return super
      end

      @resolver.resolve_node(node)
    end
  end
end
