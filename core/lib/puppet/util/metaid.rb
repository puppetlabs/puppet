class Object
  # The hidden singleton lurks behind everyone
  def singleton_class; class << self; self; end; end
  def meta_eval(&blk); singleton_class.instance_eval(&blk); end

  # Adds methods to a singleton_class
  def meta_def(name, &blk)
    meta_eval { define_method name, &blk }
  end

  # Remove singleton_class methods.
  def meta_undef(name, &blk)
    meta_eval { remove_method name }
  end

  # Defines an instance method within a class
  def class_def(name, &blk)
    class_eval { define_method name, &blk }
  end
end

