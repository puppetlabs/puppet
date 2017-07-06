<% define 'CallLocal1', :for => Object do %>
	<% expand 'Local1' %>
<% end %>

<% define_local 'Local1', :for => Object do %>
	Local1
<% end %>

