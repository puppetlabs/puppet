class Spec
  attr_reader :regex

  def initialize(*_)
  end

  def match(files)
    raise "Unimplemented"
  end

  def inclusive?
    true
  end
end
