classdef TreeRefreshVisitor < handle
  methods
    function visit(self, node)
      if node.isLeaf
        node.epochList.refresh();
      end
    end
  end
end

