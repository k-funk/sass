module Sass::Script::Tree
  # A SassScript parse node representing a variable.
  class Variable < Node
    # The name of the variable.
    #
    # @return [String]
    attr_reader :name

    # The underscored name of the variable.
    #
    # @return [String]
    attr_reader :underscored_name

    # @param name [String] See \{#name}
    def initialize(name)
      @name = name
      @underscored_name = name.gsub(/-/, "_")
      super()
    end

    # @return [String] A string representation of the variable
    def inspect(opts = {})
      "$#{dasherize(name, opts)}"
    end
    alias_method :to_sass, :inspect

    # Returns an empty array.
    #
    # @return [Array<Node>] empty
    # @see Node#children
    def children
      []
    end

    # @see Node#deep_copy
    def deep_copy
      dup
    end

    def to_ruby(environment)
      ruby = "begin\n"
      name = environment.ident_for_str(name, :var)
      unless environment.local_var?(name)
        name = "@#{name}"
        ruby << 'Sass::SyntaxError.new("Undefined variable: \"$#{self.name}\".") unless #{name}\n'
      end
      
      <<-RUBY
          if #{name}.is_a?(Sass::Script::Value::Number) && #{name}.original
            #{name} = #{name}.dup
            #{name}.original = nil
          end
          #{name}
        end
      RUBY
    end

    protected

    # Evaluates the variable.
    #
    # @param environment [Sass::Environment] The environment in which to evaluate the SassScript
    # @return [Sass::Script::Value] The SassScript object that is the value of the variable
    # @raise [Sass::SyntaxError] if the variable is undefined
    def _perform(environment)
      val = environment.var(name)
      raise Sass::SyntaxError.new("Undefined variable: \"$#{name}\".") unless val
      if val.is_a?(Sass::Script::Value::Number) && val.original
        val = val.dup
        val.original = nil
      end
      val
    end
  end
end
