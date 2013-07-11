# A provider of labels for bindings model object, producing a human name for the model object.
# @api private
#
class Puppet::Pops::Binder::BindingsLabelProvider < Puppet::Pops::LabelProvider
  def initialize
    @@label_visitor ||= Puppet::Pops::Visitor.new(self,"label",0,0)
  end

  # Produces a label for the given object without article.
  # @return [String] a human readable label
  #
  def label o
   @@label_visitor.visit(o)
  end

  def label_PObjectType o                       ; "#{Puppet::Pops::Types::TypeFactory.label(o)}" end
  def label_ProducerDescriptor o                ; "Producer"                                     end
  def label_NonCachingProducerDescriptor o      ; "Non Caching Producer"                         end
  def label_ConstantProducerDescriptor o        ; "Producer['#{o.value}']"                       end
  def label_EvaluatingProducerDescriptor o      ; "Evaluating Producer"                          end
  def label_InstanceProducerDescriptor o        ; "Producer[#{o.class_name}]"                    end
  def label_LookupProducerDescriptor o          ; "Lookup Producer[#{o.name}]"                   end
  def label_HashLookupProducerDescriptor o      ; "Hash Lookup Producer[#{o.name}][#{o.key}]"    end
  def label_FirstFoundProducerDescriptor o      ; "First Found Producer"                         end
  def label_ProducerProducerDescriptor o        ; "Producer[Producer]"                           end
  def label_MultibindProducerDescriptor o       ; "Multibind Producer"                           end
  def label_ArrayMultibindProducerDescriptor o  ; "Array Multibind Producer"                     end
  def label_HashMultibindProducerDescriptor o   ; "Hash Multibind Producer"                      end
  def label_Binding o                           ; "Binding"                                      end
  def label_Multibinding o                      ; "Multibinding"                                 end
  def label_MultibindContribution o             ; "Multibind Contribution"                       end
  def label_Bindings o                          ; "Bindings"                                     end
  def label_NamedBindings o                     ; "Named Bindings"                               end
  def label_Category o                          ; "Category '#{o.categorization}/#{o.value}'"    end
  def label_CategorizedBindings o               ; "Categorized Bindings"                         end
  def label_LayeredBindings o                   ; "Layered Bindings"                             end
  def label_NamedLayer o                        ; "Layer '#{o.name}'"                            end
  def label_EffectiveCategories o               ; "Effective Categories"                         end

end
