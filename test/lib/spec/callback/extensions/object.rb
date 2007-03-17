module Callback
  module InstanceMethods
    # Registers a callback for the event on the object. The callback can either be a block or a proc.
    # When the callbacks are notified, the return value of the proc is passed to the caller.
    def register_callback(event, callback_proc=nil, &callback_block)
      callbacks.define(event, callback_proc, &callback_block)
    end

    # Removes the callback from the event. The callback proc must be the same
    # object as the one that was passed to register_callback.
    def unregister_callback(event, callback_proc)
      callbacks.undefine(event, callback_proc)
    end

    protected
    # Notifies the callbacks registered with the event on the object. Arguments can be passed to the callbacks.
    # An error handler may be passed in as a block. If there is an error, the block is called with
    # error object as an argument.
    # An array of the return values of the callbacks is returned.
    def notify_callbacks(event, *args, &error_handler)
      callbacks.notify(event, *args, &error_handler)
    end

    def notify_class_callbacks(event, *args, &error_handler)
      self.class.send(:notify_callbacks, event, *args, &error_handler)      
    end

    # The CallbackContainer for this object.
    def callbacks
      @callbacks ||= CallbackContainer.new
    end
  end
end

class Object
  include Callback::InstanceMethods
end