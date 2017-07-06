
<% define 'GenerateMetamodel', :for => EPackage do |filename| %>
  <% file filename do %>
    require 'rgen/metamodel_builder'
    <%nl%>
    <% if needClassReorder? %>
      <% expand 'GeneratePackagesOnly' %>
      <% expand 'GenerateClassesReordered' %>
    <% else %>
      <% expand 'GeneratePackage' %>
    <% end %>
    <%nl%>
    <% expand 'GenerateAssocs' %>
  <% end %>
<% end %>
    
<% define 'GeneratePackage', :for => EPackage do %>
  module <%= moduleName %><% iinc %>
    extend RGen::MetamodelBuilder::ModuleExtension
    include RGen::MetamodelBuilder::DataTypes
    <% expand 'annotations::Annotations' %>
    <%nl%>
    <% expand 'EnumTypes' %>
    <% for c in ownClasses %><%nl%>
      <% expand 'ClassHeader', this, :for => c %><%iinc%>
        <% if c.abstract %>abstract<% end %>
        <% expand 'annotations::Annotations', :for => c %>
        <% expand 'Attribute', this, :foreach => c.eAttributes %>
        <%idec%>
      end
    <% end %><%nl%>
    <% for p in eSubpackages %>
      <%nl%><% expand 'GeneratePackage', :for => p %>
    <% end %><%idec%>
  end
<% end %>

<% define 'GenerateClassesReordered', :for => EPackage do %>
  <% for c in allClassesSorted %><%nl%>
    <% expand 'ClassHeaderFullyQualified', this, :for => c %><%iinc%>
      <% if c.abstract %>abstract<% end %>
      <% expand 'annotations::Annotations', :for => c %>
      <% expand 'Attribute', this, :foreach => c.eAttributes %>
      <%idec%>
    end
  <% end %><%nl%>
<% end %>

<% define 'GeneratePackagesOnly', :for => EPackage do %>
  module <%= moduleName %><% iinc %>
    extend RGen::MetamodelBuilder::ModuleExtension
    include RGen::MetamodelBuilder::DataTypes
    <% expand 'annotations::Annotations' %>
    <%nl%>
    <% expand 'EnumTypes' %>
    <% for p in eSubpackages %>
      <%nl%><% expand 'GeneratePackagesOnly', :for => p %>
    <% end %><%idec%>
  end
<% end %>

<% define 'Attribute', :for => EAttribute do |rootp| %>
  <% if upperBound == 1%>has_attr<% else %>has_many_attr<% end %> '<%= name %>', <%nows%>
  <% if eType.is_a?(EEnum) %><%nows%>
    <%= eType.qualifiedClassifierName(rootp) %><%nows%>
  <% else %><%nows%>
    <%= eType && eType.instanceClass.to_s %><%nows%>
  <% end %><%nows%>
  <% for p in RGen::MetamodelBuilder::Intermediate::Attribute.properties %>
    <% unless p == :name || (p == :upperBound && (upperBound == 1 || upperBound == -1)) || 
      RGen::MetamodelBuilder::Intermediate::Attribute.default_value(p) == getGeneric(p) %>
        , :<%=p%> => <%nows%>
        <% if getGeneric(p).is_a?(String) %>
          "<%= getGeneric(p) %>"<%nows%>
        <% elsif getGeneric(p).is_a?(Symbol) %>
          :<%= getGeneric(p) %><%nows%>
        <% else %>
          <%= getGeneric(p) %><%nows%>
        <% end %>
    <% end %>
  <% end %>
  <%ws%><% expand 'annotations::Annotations' %><%nl%>
<% end %>

<% define 'EnumTypes', :for => EPackage do %>
  <% for enum in eClassifiers.select{|c| c.is_a?(EEnum)} %>
    <%= enum.name %> = Enum.new(:name => '<%= enum.name %>', :literals =>[ <%nows%>
    <%= enum.eLiterals.collect { |lit| ":"+(lit.name =~ /^\d|\W/ ? "'"+lit.name+"'" : lit.name) }.join(', ') %> ])
  <% end %>
<% end %>

<% define 'GenerateAssocs', :for => EPackage do %>
  <% refDone = {} %>
  <% for ref in eAllClassifiers.select{|c| c.is_a?(EClass)}.eReferences %>
    <% if !refDone[ref] && ref.eOpposite %>
      <% ref = ref.eOpposite if ref.eOpposite.containment %>
      <% refDone[ref] = refDone[ref.eOpposite] = true %>
      <% if !ref.many && !ref.eOpposite.many %>
        <% if ref.containment %>
          <% expand 'Reference', "contains_one", this, :for => ref %>
        <% else %>
          <% expand 'Reference', "one_to_one", this, :for => ref %>
        <% end %>
      <% elsif !ref.many && ref.eOpposite.many %>
        <% expand 'Reference', "many_to_one", this, :for => ref %>
      <% elsif ref.many && !ref.eOpposite.many %>
        <% if ref.containment %>
          <% expand 'Reference', "contains_many", this, :for => ref %>
        <% else %>
          <% expand 'Reference', "one_to_many", this, :for => ref %>
        <% end %>
      <% elsif ref.many && ref.eOpposite.many %>
        <% expand 'Reference', "many_to_many", this, :for => ref %>
      <% end %>
      <% expand 'annotations::Annotations', :for => ref %><%nl%>
    <% elsif !refDone[ref] %>
      <% refDone[ref] = true %>
      <% if !ref.many %>
        <% if ref.containment %>
          <% expand 'Reference', "contains_one_uni", this, :for => ref %>
        <% else %>
          <% expand 'Reference', "has_one", this, :for => ref %>
        <% end %>
      <% elsif ref.many %>
        <% if ref.containment %>
          <% expand 'Reference', "contains_many_uni", this, :for => ref %>
        <% else %>
          <% expand 'Reference', "has_many", this, :for => ref %>
        <% end %>
      <% end %>
      <% expand 'annotations::Annotations', :for => ref %><%nl%>
    <% end %>
  <% end %>
<% end %>

<% define 'Reference', :for => EReference do |cmd, rootpackage| %>
  <%= eContainingClass.qualifiedClassifierName(rootpackage) %>.<%= cmd %> '<%= name %>', <%= eType && eType.qualifiedClassifierName(rootpackage) %><%nows%>
  <% if eOpposite %><%nows%>
    , '<%= eOpposite.name%>'<%nows%>
  <% end %><%nows%>
  <% pset = RGen::MetamodelBuilder::Intermediate::Reference.properties.reject{|p| p == :name || p == :upperBound || p == :containment} %>
  <% for p in pset.reject{|p| RGen::MetamodelBuilder::Intermediate::Reference.default_value(p) == getGeneric(p)} %>
      , :<%=p%> => <%=getGeneric(p)%><%nows%>
  <% end %>
  <% if eOpposite %>
    <% for p in pset.reject{|p| RGen::MetamodelBuilder::Intermediate::Reference.default_value(p) == eOpposite.getGeneric(p)} %>
        , :opposite_<%=p%> => <%=eOpposite.getGeneric(p)%><%nows%>
    <% end %>
  <% end %><%ws%>
<% end %>

<% define 'ClassHeader', :for => EClass do |rootp| %>
  class <%= classifierName %> < <% nows %>
  <% if eSuperTypes.size > 1 %><% nows %>
    RGen::MetamodelBuilder::MMMultiple(<%= eSuperTypes.collect{|t| t.qualifiedClassifierNameIfRequired(rootp)}.join(', ') %>)
  <% elsif eSuperTypes.size > 0 %><% nows %>
    <%= eSuperTypes.first.qualifiedClassifierNameIfRequired(rootp) %>
  <% else %><% nows %>
    RGen::MetamodelBuilder::MMBase
  <% end %>
<% end %>

<% define 'ClassHeaderFullyQualified', :for => EClass do |rootp| %>
  class <%= qualifiedClassifierName(rootp) %> < <% nows %>
  <% if eSuperTypes.size > 1 %><% nows %>
    RGen::MetamodelBuilder::MMMultiple(<%= eSuperTypes.collect{|t| t.qualifiedClassifierName(rootp)}.join(', ') %>)
  <% elsif eSuperTypes.size > 0 %><% nows %>
    <%= eSuperTypes.first.qualifiedClassifierName(rootp) %>
  <% else %><% nows %>
    RGen::MetamodelBuilder::MMBase
  <% end %>
<% end %>
