require 'yaml'

class IdStore
  def initialize(fileName=nil)
    if fileName
      raise "Base directory does not exist: #{File.dirname(fileName)}" \
        unless File.exist?(File.dirname(fileName))
      @idsFileName = fileName
    end
    @idHash = nil
  end
  
  def idHash
    load unless @idHash
    @idHash
  end
  
  def load
    if @idsFileName && File.exist?(@idsFileName)
      @idHash = YAML.load_file(@idsFileName) || {}
    else
      @idHash = {}
    end
  end
  
  def store
    return unless @idsFileName
    File.open(@idsFileName,"w") do |f|
      YAML.dump(@idHash, f)
    end
  end
end