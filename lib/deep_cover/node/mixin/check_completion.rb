require_relative 'executed_after_children'

module DeepCover
  module Node::Mixin
    module CheckCompletion
      def check_completion(outer:'(%{node})', inner:'(%{node})')
        has_tracker :completion
        include ExecutedAfterChildren
        alias_method :flow_completion_count, :completion_tracker_hits
        pre, post = outer.split('%{node}')
        # The local=local is to avoid Ruby warning about "Possible use of value in void context"
        define_method(:rewrite) { "#{pre}(%{local}=#{inner};%{completion_tracker};%{local}=%{local})#{post}" }
      end
    end
  end
end
