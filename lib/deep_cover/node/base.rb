require 'backports/2.1.0/enumerable/to_h'

module DeepCover
  # Base class to handle covered nodes.
  class Node < Parser::AST::Node
    attr_reader :context, :index, :nb, :parent

    def initialize(base_node, context, parent, index = 0)
      @context = context
      augmented_children = base_node.children.map.with_index { |child, child_index| self.class.augment(child, context, self, child_index) }
      @nb = context.create_node_nb
      @tracker_offset = context.allocate_trackers(self.class::TRACKERS.size).begin
      @parent = parent
      @index = index
      super(base_node.type, augmented_children, location: base_node.location)
    end

    ### High level API for coverage purposes

    # Returns an array of character numbers (in the original buffer) that
    # pertain exclusively to this node (and thus not to any children).
    def proper_range
      return [] unless location
      location.expression.to_a - children.flat_map{|n| n.respond_to?(:location) && n.location && n.location.expression.to_a }
    end

    def [](v)
      children[v]
    end

    # Returns true iff it is executable and if was successfully executed
    def was_executed?
      # There is a rare case of non executable nodes that have important data in runs / full_runs,
      # like `if cond; end`, so make sure it's actually executable first...
      executable? && proper_runs > 0
    end

    # Returns the number of times it changed the usual control flow (e.g. raised, returned, ...)
    def interrupts
      runs - full_runs
    end

    ### These are refined by subclasses

    # Returns true iff it is executable. Keywords like `end` are not executable, but literals like `42` are executable.
    def executable?
      true
    end

    # Returns the number of times it was executed (completely or not)
    def runs
      parent.child_runs(self)
    end

    def proper_runs
      runs
    end

    # Returns the number of time this child_node was executed (completely or not)
    def child_runs(child)
      prev = child.previous_sibbling
      if prev
        prev.full_runs
      else
        runs
      end
    end

    # Returns the number of times it was fully ran
    def full_runs
      last = children_nodes.last
      return last.full_runs if last
      runs
    end

    # Code to add before the node for covering purposes (or `nil`)
    def prefix
    end

    def child_prefix(child)
    end

    def full_prefix
      "#{prefix}#{parent.child_prefix(self)}"
    end

    # Code to add after the node for covering purposes (or `nil`)
    def suffix
    end

    def child_suffix(child)
    end

    def full_suffix
      "#{parent.child_suffix(self)}#{suffix}"
    end

    ### Singleton methods
    class << self

      ### These are refined by subclasses

      # Returns a subclass or the base Node, according to type
      def factory(type, **)
        unless const_defined?(:CHILDREN) || self == Node || self < NodeBehavior::Static
          warn "Class #{self} has children but hasn't declared them using has_children"
        end
        class_name = type.capitalize
        const_defined?(class_name) ? const_get(class_name) : Node
      end

      # Override if a particular class associated for a child must
      # be changed. `nil` is interpreted the same as `self`.
      def reclassify(base_node)
      end

      ### Public API

      # Augment creates a covered node from the child_base_node.
      # It gives both the parent class and the child class a chance
      # to decide the class of the child with `factory` and `reclassify`
      # respectively.
      def augment(child_base_node, context, parent, child_index = 0)
        # Skip children that aren't node themselves (e.g. the `method` child of a :def node)
        return child_base_node unless child_base_node.is_a? Parser::AST::Node
        klass = factory(child_base_node.type, child_index: child_index)
        klass = klass.reclassify(child_base_node) || klass
        klass.new(child_base_node, context, parent, child_index)
      end

      ### Internal

      # Creates methods to return the children corresponding with the given `names`,
      # alias for `next_instruction`.
      # Also creates constants for the indices of the children.
      def has_children(*names, next_instruction: false)
        map = {}
        i = 0
        names.each do |name|
          if name.to_s.end_with?('__rest')
            name = name.to_s.gsub(/__rest$/, '')
            nb_after = names.size - i - 1
            map[name] = i..(-1-nb_after)

            # Now we cound from the end
            i = -nb_after
          else
            map[name] = i
            i += 1
          end
        end

        map.each do |name, i|
          class_eval <<-end_eval, __FILE__, __LINE__
            def #{name}
              children[#{i}]
            end
            #{name.upcase} = #{i}
          end_eval
        end
        alias_method :next_instruction, next_instruction if next_instruction
        const_set :CHILDREN, map
      end

      def has_trackers(*names)
        const_set :TRACKERS, names.each_with_index.to_h
        names.each_with_index do |name, i|
          class_eval <<-end_eval, __FILE__, __LINE__
            def #{name}_tracker_source
              context.tracker_source(@tracker_offset + #{i})
            end
            def #{name}_tracker_hits
              context.tracker_hits(@tracker_offset + #{i})
            end
          end_eval
        end
      end

      def has_tracker(tracker) # Allow singular form
        has_trackers(tracker)
      end
    end
    has_trackers

    ### Public API

    def children_nodes
      children.select{|c| c.is_a? Node }
    end

    def next_sibbling
      parent.children[(@index+1)..-1].detect { |sibling| sibling.is_a?(Node) }
    end

    def previous_sibbling
      parent.children[0...@index].reverse.detect { |sibling| sibling.is_a?(Node) }
    end

    ### Internal API

    def each_node(order = :postorder, &block)
      return to_enum :each_node, order unless block_given?
      yield self unless order == :postorder
      children_nodes.each do |child|
        child.each_node(order, &block)
      end
      yield self if order == :postorder
      self
    end

    def each_branch(order = :postorder, &block)
      return to_enum :each_branch, order unless block_given?
      each_node(order) { |node| yield node if node.is_a? Branch }
    end

    def line_cover
      return unless ex = loc && loc.expression
      context.line_hit(ex.line - 1, runs)
      children_nodes.each(&:line_cover)
    end

    def fancy_type
      class_name = self.class.to_s.rpartition('::').last
      t = super
      t.casecmp(class_name) == 0 ? t : "#{t}[#{class_name}]"
    end

  end
end
