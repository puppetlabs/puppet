# Support code for running stuff with warnings disabled.
module Kernel
  def with_verbose_disabled
    verbose, $VERBOSE = $VERBOSE, nil
    result = yield
    $VERBOSE = verbose
    return result
  end
end
