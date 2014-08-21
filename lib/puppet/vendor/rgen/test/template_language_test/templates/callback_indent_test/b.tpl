<% define 'do_callback', :for => Object do %>
  <%iinc%>
  <% expand 'a::callback' %>
  <%idec%> 
<% end %>
