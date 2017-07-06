<% define 'Test', :for => Object do %>
	<% expand 'sub1::Sub1' %>
	<% expand 'sub1/sub1::Sub1' %>
<% end %>