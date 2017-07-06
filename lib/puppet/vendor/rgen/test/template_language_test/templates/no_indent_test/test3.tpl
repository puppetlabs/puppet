<% define 'Test', :for => Object do %>
<%iinc%>
	l1<% expand 'Call1' %>
<%idec%>
<% end %>

<% define 'Call1', :for => Object do %>
	<---
	l2
<% end %>
