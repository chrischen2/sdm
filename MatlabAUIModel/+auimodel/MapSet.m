% set class for string typed members
classdef MapSet < handle
  properties(SetAccess=private)
    elements;
  end

  properties(Access=private)
    map;
  end

  methods
    function self = MapSet()
      import containers.Map;
      self.map = Map();
    end

    function elems = get.elements(self)
      elems = self.map.keys;
    end

    function add(self, element)
      if isa(element, 'auimodel.MapSet')
        elems = element.map.keys();

        for i = 1 : length(elems)
          self.add(elems{i});
        end

        return;
      end

      if ~ self.map.isKey(element)
        self.map(element) = [];
      end
    end

    function remove(self, element)
      self.map.remove(element);
    end

    function result = contains(self, element)
      result = self.map.isKey(element);
    end

    function display(self)
      display(sprintf('\nelements =\n'));
      display(self.map.keys);
    end
  end
end

