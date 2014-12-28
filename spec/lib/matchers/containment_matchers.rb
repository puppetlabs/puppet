module ContainmentMatchers
  class ContainClass
    def initialize(containee)
      @containee = containee
    end

    def in(container)
      @container = container
      self
    end

    def matches?(catalog)
      @catalog = catalog

      raise ArgumentError, "You must set the container using #in" unless @container

      @container_resource = catalog.resource("Class", @container)
      @containee_resource = catalog.resource("Class", @containee)

      if @containee_resource && @container_resource
        catalog.edge?(@container_resource, @containee_resource)
      else
        false
      end
    end

    def failure_message
      message = "Expected #{@catalog.to_dot} to contain Class #{@containee.inspect} inside of Class #{@container.inspect} but "

      missing = []
      if @container_resource.nil?
        missing << @container
      end
      if @containee_resource.nil?
        missing << @containee
      end

      if ! missing.empty?
        message << "the catalog does not contain #{missing.map(&:inspect).join(' or ')}"
      else
        message << "no containment relationship exists"
      end

      message
    end
  end

  # expect(catalog).to contain_class(containee).in(container)
  def contain_class(containee)
    ContainClass.new(containee)
  end
end
