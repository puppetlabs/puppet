module Callback
  class CallbackContainer
    def initialize
      @callback_registry = Hash.new do |hash, key|
        hash[key] = Array.new
      end
    end

    # Defines the callback with the key in this container.
    def define(key, callback_proc=nil, &callback_block)
      callback = extract_callback(callback_block, callback_proc) do
        raise "You must define the callback that accepts the call method."
      end
      @callback_registry[key] << callback
      callback
    end

    # Undefines the callback with the key in this container.
    def undefine(key, callback_proc)
      callback = extract_callback(callback_proc) do
        raise "You may only undefine callbacks that use the call method."
      end
      @callback_registry[key].delete callback
      callback
    end

    # Notifies the callbacks for the key. Arguments may be passed.
    # An error handler may be passed in as a block. If there is an error, the block is called with
    # error object as an argument.
    # An array of the return values of the callbacks is returned.
    def notify(key, *args, &error_handler)
      @callback_registry[key].collect do |callback|
        begin
          callback.call(*args)
        rescue Exception => e
          yield(e) if error_handler
        end
      end
    end

    # Clears all of the callbacks in this container.
    def clear
      @callback_registry.clear
    end

    protected
    def extract_callback(first_choice_callback, second_choice_callback = nil)
      callback = nil
      if first_choice_callback
        callback = first_choice_callback
      elsif second_choice_callback
        callback = second_choice_callback
      end
      unless callback.respond_to? :call
        yield
      end
      return callback
    end
  end
end
