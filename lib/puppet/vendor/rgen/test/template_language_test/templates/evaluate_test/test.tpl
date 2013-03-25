<% define 'Test', :for => Object do %>
	<%= [1,2,3,4].collect{|n| evaluate 'Eval', :for => n}.join %>
<% end %>

<% define 'Eval', :for => Object do %>
	xx<%= this %>xx<%nows%>
<% end %>
