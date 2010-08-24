hostclass "foobar" do
  notify "this is a test", "loglevel" => "warning"
end

node "default" do
  acquire "foobar"
end
