classdef TreeRefresher < handle
  methods(Static)
    function refresh(node)
      if ~ isa(node, 'auimodel.EpochTree')
        error('Argument must be an EpochTree instance.');
      end

      visitor = auimodel.TreeRefreshVisitor();
      node.accept(visitor);
    end
  end
end

