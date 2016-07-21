module Puppet::Pops
module Model
# A provider of labels for model object, producing a human name for the model object.
# As an example, if object is an ArithmeticExpression with operator +, `#a_an(o)` produces "a '+' Expression",
# #the(o) produces "the + Expression", and #label produces "+ Expression".
#
class ModelLabelProvider
  include LabelProvider

  def initialize
    @@label_visitor ||= Visitor.new(self,"label",0,0)
  end

  # Produces a label for the given objects type/operator without article.
  # If a Class is given, its name is used as label
  #
  def label o
    @@label_visitor.visit_this_0(self, o)
  end

  def label_Factory o                     ; label(o.current)                    end
  def label_Array o                       ; "Array"                             end
  def label_LiteralInteger o              ; "Literal Integer"                   end
  def label_LiteralFloat o                ; "Literal Float"                     end
  def label_ArithmeticExpression o        ; "'#{o.operator}' expression"        end
  def label_AccessExpression o            ; "'[]' expression"                   end
  def label_MatchExpression o             ; "'#{o.operator}' expression"        end
  def label_CollectExpression o           ; label(o.query)                      end
  def label_EppExpression o               ; "Epp Template"                      end
  def label_ExportedQuery o               ; "Exported Query"                    end
  def label_VirtualQuery o                ; "Virtual Query"                     end
  def label_QueryExpression o             ; "Collect Query"                     end
  def label_ComparisonExpression o        ; "'#{o.operator}' expression"        end
  def label_AndExpression o               ; "'and' expression"                  end
  def label_OrExpression o                ; "'or' expression"                   end
  def label_InExpression o                ; "'in' expression"                   end
  def label_AssignmentExpression o        ; "'#{o.operator}' expression"        end
  def label_AttributeOperation o          ; "'#{o.operator}' expression"        end
  def label_LiteralList o                 ; "Array Expression"                  end
  def label_LiteralHash o                 ; "Hash Expression"                   end
  def label_KeyedEntry o                  ; "Hash Entry"                        end
  def label_LiteralBoolean o              ; "Boolean"                           end
  def label_TrueClass o                   ; "Boolean"                           end
  def label_FalseClass o                  ; "Boolean"                           end
  def label_LiteralString o               ; "String"                            end
  def label_LambdaExpression o            ; "Lambda"                            end
  def label_LiteralDefault o              ; "'default' expression"              end
  def label_LiteralUndef o                ; "'undef' expression"                end
  def label_LiteralRegularExpression o    ; "Regular Expression"                end
  def label_Nop o                         ; "Nop Expression"                    end
  def label_NamedAccessExpression o       ; "'.' expression"                    end
  def label_NilClass o                    ; "Undef Value"                       end
  def label_NotExpression o               ; "'not' expression"                  end
  def label_VariableExpression o          ; "Variable"                          end
  def label_TextExpression o              ; "Expression in Interpolated String" end
  def label_UnaryMinusExpression o        ; "Unary Minus"                       end
  def label_UnfoldExpression o            ; "Unfold"                            end
  def label_BlockExpression o             ; "Block Expression"                  end
  def label_ConcatenatedString o          ; "Double Quoted String"              end
  def label_HeredocExpression o           ; "'@(#{o.syntax})' expression"       end
  def label_HostClassDefinition o         ; "Host Class Definition"             end
  def label_FunctionDefinition o          ; "Function Definition"               end
  def label_NodeDefinition o              ; "Node Definition"                   end
  def label_SiteDefinition o              ; "Site Definition"                   end
  def label_ResourceTypeDefinition o      ; "'define' expression"               end
  def label_ResourceOverrideExpression o  ; "Resource Override"                 end
  def label_Parameter o                   ; "Parameter Definition"              end
  def label_ParenthesizedExpression o     ; "Parenthesized Expression"          end
  def label_IfExpression o                ; "'if' statement"                    end
  def label_UnlessExpression o            ; "'unless' Statement"                end
  def label_CallNamedFunctionExpression o ; "Function Call"                     end
  def label_CallMethodExpression o        ; "Method call"                       end
  def label_CapabilityMapping o           ; "Capability Mapping"                end
  def label_CaseExpression o              ; "'case' statement"                  end
  def label_CaseOption o                  ; "Case Option"                       end
  def label_RenderStringExpression o      ; "Epp Text"                          end
  def label_RenderExpression o            ; "Epp Interpolated Expression"       end
  def label_RelationshipExpression o      ; "'#{o.operator}' expression"        end
  def label_ResourceBody o                ; "Resource Instance Definition"      end
  def label_ResourceDefaultsExpression o  ; "Resource Defaults Expression"      end
  def label_ResourceExpression o          ; "Resource Statement"                end
  def label_SelectorExpression o          ; "Selector Expression"               end
  def label_SelectorEntry o               ; "Selector Option"                   end
  def label_Integer o                     ; "Integer"                           end
  def label_Fixnum o                      ; "Integer"                           end
  def label_Bignum o                      ; "Integer"                           end
  def label_Float o                       ; "Float"                             end
  def label_String o                      ; "String"                            end
  def label_Regexp o                      ; "Regexp"                            end
  def label_Object o                      ; "Object"                            end
  def label_Hash o                        ; "Hash"                              end
  def label_QualifiedName o               ; "Name"                              end
  def label_QualifiedReference o          ; "Type-Name"                         end
  def label_PAnyType o                    ; "#{o}-Type" end
  def label_ReservedWord o                ; "Reserved Word '#{o.word}'"         end
  def label_CatalogCollector o            ; "Catalog-Collector"                 end
  def label_ExportedCollector o           ; "Exported-Collector"                end
  def label_TypeAlias o                   ; "Type Alias"                        end
  def label_TypeMapping o                 ; "Type Mapping"                      end
  def label_TypeDefinition o              ; "Type Definition"                   end
  def label_Application o                 ; "Application"                       end
  def label_Sensitive o                   ; "Sensitive"                         end

  def label_PResourceType o
    if o.title
      "#{o} Resource-Reference"
    else
      "#{o}-Type"
    end
  end

  def label_Resource o
    'Resource Statement'
  end


  def label_Class o
    if o <= Types::PAnyType
      simple_name = o.name.split('::').last
      simple_name[1..-5] + "-Type"
    else
      o.name
    end
  end
end
end
end
