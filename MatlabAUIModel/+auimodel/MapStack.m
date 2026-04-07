classdef MapStack < handle
  properties(SetAccess=protected)
    count;
  end

  properties(Hidden)
    containersMap = [];
  end

  methods
    function self = MapStack()
      self.containersMap = containers.Map(-1, auimodel.Null);
      self.count = 0;
    end

    function push(self, value, iterate)
      if nargin > 2 && iscell(value)  && iterate
        for i = length(value) : -1 : 1
          self.push(value{i});
        end
      else
        self.containersMap(self.count + 1) = value;
        self.count = self.count + 1;
      end
    end

    function value = pop(self)
      if self.count > 0
        value = self.containersMap(self.count);
        self.count = self.count - 1;
      else
        value = [];
      end
    end
  end
end

