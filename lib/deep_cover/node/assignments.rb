require_relative "const"

module DeepCover
  class Node
    class VariableAssignment < Node
      has_child var_name: Symbol
      has_child value: [Node, nil]

      def execution_count
        return super unless value
        value.flow_completion_count
      end
    end
    Cvasgn = Gvasgn = Ivasgn = Lvasgn = VariableAssignment

    class Casgn < Node
      has_child cbase: [Cbase, Const, nil]
      has_child var_name: Symbol
      has_child value: [Node, nil]

      def execution_count
        return super unless value
        value.flow_completion_count
      end
    end

    class Mlhs < Node
      has_extra_children being_set: Node
      # TODO
    end

    module AlternateStrategy
      # Instead of deducing completion completion from entry,
      # We go the other way, deducing entry from completion.
      def flow_completion_count
        s = next_sibling
        s ? s.flow_entry_count : parent.flow_completion_count
      end

      def flow_entry_count
        flow_completion_count
      end
    end

    class MasgnSetter < Node
      include AlternateStrategy
      has_tracker :entry
      has_child receiver: Node,
                rewrite: '(%{node}).tap{%{entry_tracker}}',
                flow_entry_count: :entry_tracker_hits
      has_child method_name: Symbol
      has_child arg: [Node, nil] # When method is :[]=

      alias_method :flow_entry_count, :entry_tracker_hits
    end

    class MasgnVariableAssignment < Node
      include AlternateStrategy
      has_child var_name: Symbol
    end

    MASGN_BASE_MAP = {
      cvasgn: MasgnVariableAssignment, gvasgn: MasgnVariableAssignment,
      ivasgn: MasgnVariableAssignment, lvasgn: MasgnVariableAssignment,
      send: MasgnSetter,
    }
    class MasgnSplat < Node
      include AlternateStrategy
      has_child rest_arg: MASGN_BASE_MAP
    end

    class MasgnLeftSide < Node
      include AlternateStrategy
      has_extra_children receivers: {
        splat: MasgnSplat,
        mlhs: MasgnLeftSide,
        **MASGN_BASE_MAP,
      }
      def flow_completion_count
        parent.flow_completion_count
      end
    end

    # a, b = ...
    class Masgn < Node
      check_completion

      has_child left: {mlhs: MasgnLeftSide}
      has_child value: Node

      def execution_count
        value.flow_completion_count
      end

      def children_nodes_in_flow_order
        [value, left]
      end
    end

    class VariableOperatorAssign < Node
      has_child var_name: Symbol
    end

    class SendOperatorAssign < Node
      has_child receiver: [Node, nil]
      has_child method_name: Symbol
      has_extra_children arguments: Node
    end

    # foo += bar
    class Op_asgn < Node
      check_completion
      has_tracker :reader
      has_child receiver: {
        lvasgn: VariableOperatorAssign, ivasgn: VariableOperatorAssign,
        cvasgn: VariableOperatorAssign, gvasgn: VariableOperatorAssign,
        casgn: Casgn, # TODO
        send: SendOperatorAssign,
      }
      has_child operator: Symbol
      has_child value: Node, rewrite: '(%{reader_tracker};%{node})', flow_entry_count: :reader_tracker_hits
      def execution_count
        flow_completion_count
      end
    end

    # foo ||= bar, foo &&= base
    class BooleanAssignment < Node
      check_completion
      has_tracker :long_branch
      has_child receiver: {
        lvasgn: VariableOperatorAssign, ivasgn: VariableOperatorAssign,
        cvasgn: VariableOperatorAssign, gvasgn: VariableOperatorAssign,
        casgn: Casgn, # TODO
        send: SendOperatorAssign,
      }
      has_child value: Node, rewrite: '(%{long_branch_tracker};%{node})', flow_entry_count: :long_branch_tracker_hits

      def execution_count
        flow_completion_count
      end
    end

    Or_asgn = And_asgn = BooleanAssignment
  end
end
