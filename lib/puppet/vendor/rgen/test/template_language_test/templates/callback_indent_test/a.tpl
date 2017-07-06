<% define 'caller', :for => Object do %>
  |before callback
  <% expand 'b::do_callback' %>
  |after callback
  <%iinc%>
  |after iinc
<% end %>

<% define 'callback', :for => Object do %>
  |in callback
<% end %>

