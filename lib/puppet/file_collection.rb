# This was a simple way to turn file names into singletons,
#
# The theory was, like:
# 1. Turn filenames into singletons.
# 2. ????
# 3. Huge memory savings!
#
# In practice it used several MB more memory overall, and it cost more CPU
# time, and it added complexity to the code.  Which was awesome.
#
# So, I gutted it.  It doesn't do anything any more, but we retain the
# external form that people included so that they don't explode so much.
#
# This should be removed from the system after a graceful deprecation period,
# probably about the time that a version of Puppet containing this change is
# the last supported version. --daniel 2012-07-17
class Puppet::FileCollection
  require 'puppet/file_collection/lookup'
end
