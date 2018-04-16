Dir.glob("#{File.dirname(__FILE__)}/modules/*/lib") do |lib|
  $: << lib
end
