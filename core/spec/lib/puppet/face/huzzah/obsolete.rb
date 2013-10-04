Puppet::Face.define(:huzzah, '1.0.0') do
  action :obsolete do
    summary "This is an action on version 1.0.0 of the face"
    when_invoked do |options| options end
  end
end
