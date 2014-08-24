<% define 'Test', :for => Object do %>
	<% expand 'local::CallLocal1' %>
<% end %>

<% define 'TestForbidden', :for => Object do %>
	<% expand 'local::Local1' %>
<% end %>
	