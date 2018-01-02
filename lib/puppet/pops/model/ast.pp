type Puppet::AST = TypeSet[{
  pcore_version => '1.0.0',
  types => {
    Locator => Object[{
      attributes => {
        'string' => String,
        'file' => String,
        'line_index' => {
          type => Optional[Array[Integer]],
          value => undef
        }
      }
    }],
    PopsObject => Object[{
    }],
    Positioned => Object[{
      parent => PopsObject,
      attributes => {
        'locator' => {
          type => Locator,
          kind => reference
        },
        'offset' => Integer,
        'length' => Integer,
        'file' => {
          type => String,
          kind => derived,
          annotations => {
             RubyMethod => { 'body' => '@locator.file' }
          }
        },
        'line' => {
          type => Integer,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@locator.line_for_offset(@offset)' }
          }
        },
        'pos' => {
          type => Integer,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@locator.pos_on_line(@offset)' }
          }
        }
      },
      equality => []
    }],
    Expression => Object[{
      parent => Positioned
    }],
    Nop => Object[{
      parent => Expression
    }],
    BinaryExpression => Object[{
      parent => Expression,
      attributes => {
        'left_expr' => Expression,
        'right_expr' => Expression
      }
    }],
    UnaryExpression => Object[{
      parent => Expression,
      attributes => {
        'expr' => Expression
      }
    }],
    ParenthesizedExpression => Object[{
      parent => UnaryExpression
    }],
    NotExpression => Object[{
      parent => UnaryExpression
    }],
    UnaryMinusExpression => Object[{
      parent => UnaryExpression
    }],
    UnfoldExpression => Object[{
      parent => UnaryExpression
    }],
    AssignmentExpression => Object[{
      parent => BinaryExpression,
      attributes => {
        'operator' => Enum['+=', '-=', '=']
      }
    }],
    ArithmeticExpression => Object[{
      parent => BinaryExpression,
      attributes => {
        'operator' => Enum['%', '*', '+', '-', '/', '<<', '>>']
      }
    }],
    RelationshipExpression => Object[{
      parent => BinaryExpression,
      attributes => {
        'operator' => Enum['->', '<-', '<~', '~>']
      }
    }],
    AccessExpression => Object[{
      parent => Expression,
      attributes => {
        'left_expr' => Expression,
        'keys' => {
          type => Array[Expression],
          value => []
        }
      }
    }],
    ComparisonExpression => Object[{
      parent => BinaryExpression,
      attributes => {
        'operator' => Enum['!=', '<', '<=', '==', '>', '>=']
      }
    }],
    MatchExpression => Object[{
      parent => BinaryExpression,
      attributes => {
        'operator' => Enum['!~', '=~']
      }
    }],
    InExpression => Object[{
      parent => BinaryExpression
    }],
    BooleanExpression => Object[{
      parent => BinaryExpression
    }],
    AndExpression => Object[{
      parent => BooleanExpression
    }],
    OrExpression => Object[{
      parent => BooleanExpression
    }],
    LiteralList => Object[{
      parent => Expression,
      attributes => {
        'values' => {
          type => Array[Expression],
          value => []
        }
      }
    }],
    KeyedEntry => Object[{
      parent => Positioned,
      attributes => {
        'key' => Expression,
        'value' => Expression
      }
    }],
    LiteralHash => Object[{
      parent => Expression,
      attributes => {
        'entries' => {
          type => Array[KeyedEntry],
          value => []
        }
      }
    }],
    BlockExpression => Object[{
      parent => Expression,
      attributes => {
        'statements' => {
          type => Array[Expression],
          value => []
        }
      }
    }],
    CaseOption => Object[{
      parent => Expression,
      attributes => {
        'values' => Array[Expression, 1, default],
        'then_expr' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    CaseExpression => Object[{
      parent => Expression,
      attributes => {
        'test' => Expression,
        'options' => {
          type => Array[CaseOption],
          value => []
        }
      }
    }],
    QueryExpression => Object[{
      parent => Expression,
      attributes => {
        'expr' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    ExportedQuery => Object[{
      parent => QueryExpression
    }],
    VirtualQuery => Object[{
      parent => QueryExpression
    }],
    AbstractAttributeOperation => Object[{
      parent => Positioned
    }],
    AttributeOperation => Object[{
      parent => AbstractAttributeOperation,
      attributes => {
        'attribute_name' => String,
        'operator' => Enum['+>', '=>'],
        'value_expr' => Expression
      }
    }],
    AttributesOperation => Object[{
      parent => AbstractAttributeOperation,
      attributes => {
        'expr' => Expression
      }
    }],
    CollectExpression => Object[{
      parent => Expression,
      attributes => {
        'type_expr' => Expression,
        'query' => QueryExpression,
        'operations' => {
          type => Array[AbstractAttributeOperation],
          value => []
        }
      }
    }],
    Parameter => Object[{
      parent => Positioned,
      attributes => {
        'name' => String,
        'value' => {
          type => Optional[Expression],
          value => undef
        },
        'type_expr' => {
          type => Optional[Expression],
          value => undef
        },
        'captures_rest' => {
          type => Optional[Boolean],
          value => undef
        }
      }
    }],
    Definition => Object[{
      parent => Expression
    }],
    NamedDefinition => Object[{
      parent => Definition,
      attributes => {
        'name' => String,
        'parameters' => {
          type => Array[Parameter],
          value => []
        },
        'body' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    FunctionDefinition => Object[{
      parent => NamedDefinition,
      attributes => {
        'return_type' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    ResourceTypeDefinition => Object[{
      parent => NamedDefinition
    }],
    Application => Object[{
      parent => NamedDefinition
    }],
    QRefDefinition => Object[{
      parent => Definition,
      attributes => {
        'name' => String
      }
    }],
    TypeAlias => Object[{
      parent => QRefDefinition,
      attributes => {
        'type_expr' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    TypeMapping => Object[{
      parent => Definition,
      attributes => {
        'type_expr' => {
          type => Optional[Expression],
          value => undef
        },
        'mapping_expr' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    TypeDefinition => Object[{
      parent => QRefDefinition,
      attributes => {
        'parent' => {
          type => Optional[String],
          value => undef
        },
        'body' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    NodeDefinition => Object[{
      parent => Definition,
      attributes => {
        'parent' => {
          type => Optional[Expression],
          value => undef
        },
        'host_matches' => Array[Expression, 1, default],
        'body' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    SiteDefinition => Object[{
      parent => Definition,
      attributes => {
        'body' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    SubLocatedExpression => Object[{
      parent => Expression,
      attributes => {
        'expr' => Expression,
        'line_offsets' => {
          type => Array[Integer],
          value => []
        },
        'leading_line_count' => {
          type => Optional[Integer],
          value => undef
        },
        'leading_line_offset' => {
          type => Optional[Integer],
          value => undef
        }
      }
    }],
    HeredocExpression => Object[{
      parent => Expression,
      attributes => {
        'syntax' => {
          type => Optional[String],
          value => undef
        },
        'text_expr' => Expression
      }
    }],
    HostClassDefinition => Object[{
      parent => NamedDefinition,
      attributes => {
        'parent_class' => {
          type => Optional[String],
          value => undef
        }
      }
    }],
    PlanDefinition => Object[{
      parent => FunctionDefinition,
    }],
    LambdaExpression => Object[{
      parent => Expression,
      attributes => {
        'parameters' => {
          type => Array[Parameter],
          value => []
        },
        'body' => {
          type => Optional[Expression],
          value => undef
        },
        'return_type' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    IfExpression => Object[{
      parent => Expression,
      attributes => {
        'test' => Expression,
        'then_expr' => {
          type => Optional[Expression],
          value => undef
        },
        'else_expr' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    UnlessExpression => Object[{
      parent => IfExpression
    }],
    CallExpression => Object[{
      parent => Expression,
      attributes => {
        'rval_required' => {
          type => Boolean,
          value => false
        },
        'functor_expr' => Expression,
        'arguments' => {
          type => Array[Expression],
          value => []
        },
        'lambda' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    CallFunctionExpression => Object[{
      parent => CallExpression
    }],
    CallNamedFunctionExpression => Object[{
      parent => CallExpression
    }],
    CallMethodExpression => Object[{
      parent => CallExpression
    }],
    Literal => Object[{
      parent => Expression
    }],
    LiteralValue => Object[{
      parent => Literal
    }],
    LiteralRegularExpression => Object[{
      parent => LiteralValue,
      attributes => {
        'value' => Any,
        'pattern' => String
      }
    }],
    LiteralString => Object[{
      parent => LiteralValue,
      attributes => {
        'value' => String
      }
    }],
    LiteralNumber => Object[{
      parent => LiteralValue
    }],
    LiteralInteger => Object[{
      parent => LiteralNumber,
      attributes => {
        'radix' => {
          type => Integer,
          value => 10
        },
        'value' => Integer
      }
    }],
    LiteralFloat => Object[{
      parent => LiteralNumber,
      attributes => {
        'value' => Float
      }
    }],
    LiteralUndef => Object[{
      parent => Literal
    }],
    LiteralDefault => Object[{
      parent => Literal
    }],
    LiteralBoolean => Object[{
      parent => LiteralValue,
      attributes => {
        'value' => Boolean
      }
    }],
    TextExpression => Object[{
      parent => UnaryExpression
    }],
    ConcatenatedString => Object[{
      parent => Expression,
      attributes => {
        'segments' => {
          type => Array[Expression],
          value => []
        }
      }
    }],
    QualifiedName => Object[{
      parent => LiteralValue,
      attributes => {
        'value' => String
      }
    }],
    ReservedWord => Object[{
      parent => LiteralValue,
      attributes => {
        'word' => String,
        'future' => {
          type => Optional[Boolean],
          value => undef
        }
      }
    }],
    QualifiedReference => Object[{
      parent => LiteralValue,
      attributes => {
        'cased_value' => String,
        'value' => {
          type => String,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@cased_value.downcase' }
          }
        }
      }
    }],
    VariableExpression => Object[{
      parent => UnaryExpression
    }],
    EppExpression => Object[{
      parent => Expression,
      attributes => {
        'parameters_specified' => {
          type => Optional[Boolean],
          value => undef
        },
        'body' => {
          type => Optional[Expression],
          value => undef
        }
      }
    }],
    RenderStringExpression => Object[{
      parent => LiteralString
    }],
    RenderExpression => Object[{
      parent => UnaryExpression
    }],
    ResourceBody => Object[{
      parent => Positioned,
      attributes => {
        'title' => {
          type => Optional[Expression],
          value => undef
        },
        'operations' => {
          type => Array[AbstractAttributeOperation],
          value => []
        }
      }
    }],
    AbstractResource => Object[{
      parent => Expression,
      attributes => {
        'form' => {
          type => Enum['exported', 'regular', 'virtual'],
          value => 'regular'
        },
        'virtual' => {
          type => Boolean,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => "@form == 'virtual' || @form == 'exported'" }
          }
        },
        'exported' => {
          type => Boolean,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => "@form == 'exported'" }
          }
        }
      }
    }],
    ResourceExpression => Object[{
      parent => AbstractResource,
      attributes => {
        'type_name' => Expression,
        'bodies' => {
          type => Array[ResourceBody],
          value => []
        }
      }
    }],
    CapabilityMapping => Object[{
      parent => Definition,
      attributes => {
        'kind' => String,
        'capability' => String,
        'component' => Expression,
        'mappings' => {
          type => Array[AbstractAttributeOperation],
          value => []
        }
      }
    }],
    ResourceDefaultsExpression => Object[{
      parent => AbstractResource,
      attributes => {
        'type_ref' => {
          type => Optional[Expression],
          value => undef
        },
        'operations' => {
          type => Array[AbstractAttributeOperation],
          value => []
        }
      }
    }],
    ResourceOverrideExpression => Object[{
      parent => AbstractResource,
      attributes => {
        'resources' => Expression,
        'operations' => {
          type => Array[AbstractAttributeOperation],
          value => []
        }
      }
    }],
    SelectorEntry => Object[{
      parent => Positioned,
      attributes => {
        'matching_expr' => Expression,
        'value_expr' => Expression
      }
    }],
    SelectorExpression => Object[{
      parent => Expression,
      attributes => {
        'left_expr' => Expression,
        'selectors' => {
          type => Array[SelectorEntry],
          value => []
        }
      }
    }],
    NamedAccessExpression => Object[{
      parent => BinaryExpression
    }],
    Program => Object[{
      parent => PopsObject,
      attributes => {
        'body' => {
          type => Optional[Expression],
          value => undef
        },
        'definitions' => {
          type => Array[Definition],
          kind => reference,
          value => []
        },
        'source_text' => {
          type => String,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@locator.string' }
          }
        },
        'source_ref' => {
          type => String,
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@locator.file' }
          }
        },
        'line_offsets' => {
          type => Array[Integer],
          kind => derived,
          annotations => {
            RubyMethod => { 'body' => '@locator.line_index' }
          }
        },
        'locator' => Locator
      }
    }]
  }
}]
