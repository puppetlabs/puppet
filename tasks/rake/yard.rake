begin
  require 'yard'

  YARD::Rake::YardocTask.new do |t|
    t.files = ['lib/**/*.rb', 'spec/**/*.rb']
  end

rescue LoadError
  # yard not installed (gem install yard)
  #   # http://yardoc.org
end
