class File
  class << self
    alias_method :exists?, :exist?
  end
end