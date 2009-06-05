module Puppet::Util::Execution
    module_function

    # Run some code with a specific environment.  Resets the environment back to
    # what it was at the end of the code.
    def withenv(hash)
        oldvals = {}
        hash.each do |name, val|
            name = name.to_s
            oldvals[name] = ENV[name]
            ENV[name] = val
        end

        yield
    ensure
        oldvals.each do |name, val|
            ENV[name] = val
        end
    end
end

