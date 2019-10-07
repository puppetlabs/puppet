# These stub the translation methods normally brought in
# by FastGettext. Used when Gettext could not be properly
# initialized.
def _(msg)
  msg
end

def n_(*args, &block)
  plural = args[2] == 1 ? args[0] : args[1]
  block ? block.call : plural
end
