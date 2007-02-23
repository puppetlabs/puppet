class Range
  
  def self.at_least(minimum_value)
    Range.new(minimum_value, infinite)
  end
  
  def self.at_most(maximum_value)
    Range.new(-infinite, maximum_value, false)
  end
  
  def self.infinite
    1/0.0
  end
  
  alias_method :__to_s__, :to_s

  def to_s
    if first.to_f.infinite? then
      return "at most #{last}"
    elsif last.to_f.infinite? then
      return "at least #{first}"
    else
      __to_s__
    end
  end
  
end