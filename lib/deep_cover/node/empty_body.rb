module DeepCover
  class Node::EmptyBody < Node
    def initialize(base_node, parent: raise, index: 0, position: ChildCanBeEmpty.last_empty_position)
      @position = position
      super(base_node, parent: parent, index: index, base_children: [])
    end

    def type
      :EmptyBody
    end

    def loc_hash
      return {} if @position == true
      {expression: @position}
    end

    def is_statement
      false
    end
  end
end
