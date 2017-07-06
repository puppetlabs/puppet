<% define 'Sub1', :for => Object do %>
	Sub1
<% end %>

<% define 'Test', :for => Object do %>
	<% expand 'Sub1' %>
	<% expand 'sub1::Sub1' %>
	<% expand 'sub1/sub1::Sub1' %>
<% end %>
