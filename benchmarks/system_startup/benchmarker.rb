class Benchmarker
  def initialize(target, size)
  end

  def setup
  end

  def generate
  end

  def run(args=nil)
    # Just running help is probably a good proxy of a full startup.
    # Simply asking for the version might also be good, but it would miss all
    # of the app searching and loading parts
    `puppet help`
  end
end
