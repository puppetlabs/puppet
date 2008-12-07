# Manage whether a test is runnable.
module PuppetTest
    module RunnableTest
        # Confine this test based on specified criteria.  The keys of the
        # hash should be the message to use if the test is not suitable,
        # and the values should be either 'true' or 'false'; true values
        # mean the test is suitable.
        def confine(hash)
            @confines ||= {}
            hash.each do |message, result|
                @confines[message] = result
            end
        end

        attr_reader :messages

        # Evaluate all of our tests to see if any of them are false
        # and thus whether this test is considered not runnable.
        def runnable?
            @messages ||= []
            if superclass.respond_to?(:runnable?) and ! superclass.runnable?
                return false
            end
            return false unless @messages.empty?
            return true unless defined? @confines
            @confines.find_all do |message, result|
                ! result
            end.each do |message, result|
                @messages << message
            end

            return @messages.empty?
        end
    end
end
