classdef MapList < handle
  properties(SetAccess=protected)
    length;
  end

  properties(Hidden)
    containersMap;
    listCellCache;
  end

  methods
    function self = MapList()
      import auimodel.*
      % initializes map to key type double and value type any
      self.containersMap = containers.Map(-1, Null);
      self.containersMap.remove(-1);
      self.length = 0;
    end

    function value = valueByIndex(self, index)
      if self.length >= index && index > 0
        value = self.containersMap(index);
      else
        value = [];
      end
    end

    function append(self, value, iterate)
      if nargin > 2 && isa(value, 'auimodel.MapList') && iterate
        listCell = value.toCell();
        self.append(listCell, true);
      elseif nargin > 2 && iscell(value) && iterate
        for i = 1 : length(value)
          self.append(value{i});
        end
      else
        index = self.length + 1;
        self.containersMap(index) = value;
        self.length = self.length + 1;
      end
    end

    function value = firstValue(self)
      if self.length > 0
        value = self.containersMap(1);
      else
        value = [];
      end
    end

    function out = map(self, functor)
      out = auimodel.MapList();

      listCell = self.toCell();
      for i = 1 : length(listCell)
        out.append( functor(listCell{i}) );
      end
    end

    function listCell = toCell(self)
      listCell = self.containersMap.values();
    end
  end
end

