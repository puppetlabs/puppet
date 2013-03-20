<% define 'ArrayDefinition', :for => CArray do %>
  <%= getType %> <%= name %>[<%= size %>] = {<%iinc%>
    <% expand 'InitValue', :foreach => initvalue, :separator => ",\r\n" %><%nl%><%idec%>
  };
  <% expand '../root::TextFromRoot' %>
  <% expand '/root::TextFromRoot' %>
<% end %>

<% define 'InitValue', :for => PrimitiveInitValue do %>
  <%= value %><%nows%>
<% end %>
