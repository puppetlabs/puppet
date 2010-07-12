# Manage whether a test is runnable.
module PuppetTest
  module RunnableTest
    # Confine this example group based on specified criteria.  This can be
    # a message and its related test either as a hash or as a single
    # message argument and a block to be evaluated at the time the confine
    # is checked.
    #
    # Examples:
    #
    # confine "Rails is not available" => Puppet.features.rails?
    #
    # confine("ActiveRecord 2.1.x") { ::ActiveRecord::VERSION::MAJOR == 2 and ::ActiveRecord::VERSION::MINOR <= 1 }
    #
    def confine(hash_or_message, &block)
      hash = block_given? ? {hash_or_message => block} : hash_or_message
      confines.update hash
    end

    # Check all confines for a given example group, starting with any
    # specified in the parent example group. If any confine test is false,
    # the example group is not runnable (and will be skipped). Note: This
    # is used directly by Rspec and is not intended for develper use.
    #
    def runnable?
      return false if superclass.respond_to?(:runnable?) and not superclass.runnable?

      confines.each do |message, is_runnable|
        is_runnable = is_runnable.call if is_runnable.respond_to?(:call)
        messages << message unless is_runnable
      end

      messages.empty?
    end

    def messages; @messages ||= [] end

    private

    def confines; @confines ||= {} end
  end

end
