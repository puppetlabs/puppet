# @summary Notify to demonstrate users::dc1 in catalog
#
# A Class that should be present in dc1 node(s) catalog
#
# @example
#   include users::dc1
class users::dc1 {
  notify { 'Adding users::dc1': }
}
