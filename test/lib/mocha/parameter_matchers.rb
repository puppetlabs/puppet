module Mocha
  
  # Used as parameters for Expectation#with to restrict the parameter values which will match the expectation.
  module ParameterMatchers; end
  
end


Dir[File.expand_path(File.join(File.dirname(__FILE__), 'parameter_matchers', "*.rb"))].each { |lib| require lib }
