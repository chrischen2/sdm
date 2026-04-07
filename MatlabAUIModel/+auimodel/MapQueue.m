% queue only suitable for small numbers of elements.  with heavy use will
% eventually overrun the bounds of the underlying map.  basically only
% reliable for tree building at the moment.
classdef MapQueue < handle
  properties(SetAccess=protected)
    count;
  end

  properties(Hidden)
    containersMap;
    startIndex;
    endIndex;
  end

  methods
    function self = MapQueue()
      self.containersMap = containers.Map(-1, auimodel.Null);
      self.count = 0;
      self.startIndex = 0;
      self.endIndex = 0;
    end

    function enqueue(self, value, iterateCell)
      if nargin > 2 && iscell(value) && iterateCell
        for i = 1 : length(value)
          self.enqueue(value{i});
        end
      else
        self.containersMap(self.startIndex + 1) = value;
        self.startIndex = self.startIndex - 1;
        self.count = self.count + 1;
      end
    end

    function value = dequeue(self)
      if self.count > 0
        value = self.containersMap(self.endIndex + 1);
        self.endIndex = self.endIndex - 1;
        self.count = self.count - 1;
      else
        value = [];
      end
    end
  end
end

