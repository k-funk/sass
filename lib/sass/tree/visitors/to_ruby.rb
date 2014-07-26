class Sass::Tree::Visitors::ToRuby < Sass::Tree::Visitors::Base
  class << self
    def visit(root, environment = nil)
      new(environment).send(:visit, root)
    end
  end

  def initialize(environment)
    @environment = environment || Sass::Environment.new
    @environment_var = @environment.unique_ident(:env)
  end

  def visit_children(parent)
    super.join("\n")
  end

  def with_parent(name)
    old_env, @environment = @environment, Sass::Environment.new(@environment)
    old_parent_var, @parent_var = @parent_var, name
    old_env_var = @environment.unique_ident(:old_env)
    "#{old_env_var}, #{@environment_var} = #{@environment_var}, ::Sass::Environment.new(#{@environment_var})\n" +
      yield + "\n" +
      "#{@environment_var} = #{old_env_var}\n"
  ensure
    @parent_var = old_parent_var
    @environment = old_env
  end

  def visit_root(node)
    root_var = @environment.unique_ident(:root)
    "#{@environment_var} = ::Sass::Environment.new\n" +
      "#{root_var} = ::Sass::Tree::RootNode.new('')\n" +
      with_parent(root_var) {yield}
  end

  def visit_comment(node)
    return '' if node.invisible?
    "#{@parent_var} << ::Sass::Tree::CommentNode.resolved(" +
      "#{interp_no_strip(node.value)}, #{node.type.inspect})"
  end

  def visit_function(node)
    name = @environment.fn_ident(node.name)
    with_parent(nil) {"def #{name}\n#{yield}\nend"}
  end

  def visit_prop(node)
    prop_var = @environment.unique_ident(:prop)
    ruby = "#{@parent_var} << #{prop_var} = ::Sass::Tree::PropNode.resolved(#{interp(node.name)}, " +
      "(#{node.value.to_ruby(@environment)}).to_s)"
    with_parent(prop_var) {ruby + yield}
  end

  def visit_return(node)
    "return #{node.expr.to_ruby(@environment)}"
  end

  def visit_rule(node)
    parser_var = @environment.unique_ident(:parser)
    selector_var = @environment.unique_ident(:selector)
    ruby = "#{parser_var} = ::Sass::SCSS::StaticParser.new(#{interp(node.rule)}, '', nil, 0)\n"
    rule_var = @environment.unique_ident(:rule)
    ruby << "#{@parent_var} << #{rule_var} = ::Sass::Tree::RuleNode.resolved(" +
      "#{parser_var}.parse_selector.resolve_parent_refs(#{@environment_var}.selector))\n"
    with_parent(rule_var) do
      ruby << "#{@environment_var}.selector = #{rule_var}.resolved_rules\n"
      ruby + yield
    end
  end

  def interp(script)
    script.map do |e|
      next e.dump if e.is_a?(String)
      "(#{e.to_ruby(@environment)}).to_s"
    end.join(" + ")
  end
end
