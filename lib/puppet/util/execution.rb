module Puppet::Util::Execution
  module_function

  # Run some code with a specific environment.  Resets the environment back to
  # what it was at the end of the code.
  def withenv(hash)
    saved = ENV.to_hash
    hash.each do |name, val|
      ENV[name.to_s] = val
    end

    yield
  ensure
    ENV.clear
    saved.each do |name, val|
      ENV[name] = val
    end
  end
end

