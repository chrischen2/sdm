classdef EpochTree < handle
  properties
    splitKey;
    splitValue;
    splitValues;

    parent;
    children;

    isLeaf;

    epochList;
    leafNodes; % contains all direct or indirect descendant leaf nodes.

    custom = struct();
  end

  properties(Hidden)
    dotLabel;
    dotEdgeLabel;
    ovationExport;
    guid;
  end

  methods(Static)
    function tree = build(source, splitKeyPaths, suppliedProjRoot)
      import auimodel.*;

      if ~ iscell(splitKeyPaths)
        MException('AUIModel:BadParam', ...
          'Second parameter must be a cell of key paths.').throw();
      end

      if isa(source, 'auimodel.EpochList')
        epochList = source;
      elseif ExportLoader.isValidExport(source)
        if nargin > 2
          epochList = EpochList(source, suppliedProjRoot);
        else
          epochList = EpochList(source);
        end
      else
        error('Must supply an EpochList or OvationExport as first param.');
      end

      pathsStack = MapStack();
      pathsStack.push(splitKeyPaths, true);

      tree = EpochTree(epochList, pathsStack, MapStack(), epochList.ovationExport);
    end
  end

  methods(Access=private)
    function self = EpochTree(epochList, forwardKeyStack, backwardKeyStack, ovationExport)

      import auimodel.*;

      self.isLeaf = 0;
      self.guid = char(java.util.UUID.randomUUID());

      % base case: there are no paths left to split on
      if forwardKeyStack.count() == 0
        self.isLeaf = 1;
        self.epochList = epochList;

        % parent will set our other properties
        return;
      end

      % advance to the next key and store it for rewinding later.
      self.splitKey = forwardKeyStack.pop();
      backwardKeyStack.push(self.splitKey);

      childMap = Map();

      keyType = class(self.splitKey);
      if strcmp(keyType, 'function_handle')
        splitValueGetter = self.splitKey;
      elseif strcmp(keyType, 'char')
        splitValueGetter = epochList.firstValue.keyPathGetter(self.splitKey, false);
      else
        error(sprintf('Split keys of class "%s" not supported.', keyType));
      end

      listCell = epochList.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};

        try
          splitValue = splitValueGetter(epoch);
        catch e
          splitValue = Null.instance;
        end

        if ~ childMap.hasKey(splitValue)
          subList = EpochList();
          subList.ovationExport = epochList.ovationExport;

          childMap.set(splitValue, subList);
        end

        childMap.get(splitValue).append(epoch);
      end

      splitValues = childMap.keys();
      child_count = length(splitValues);

      children = MapList();

      leafNodes = MapList();
      for i = 1 : child_count
        splitValue = splitValues{i};

        list = childMap.get(splitValue);
        list.populateStreamNames();

        % recursive case: we traverse along our children depth first
        node = EpochTree(list, forwardKeyStack, backwardKeyStack, ...
          ovationExport);

        node.parent = self;
        node.ovationExport = ovationExport;
        node.splitValue = splitValue;

        % if the new child is a leaf, append it to our list of leafs. otherwise
        % roll up our child branch node's ultimate leafs.
        if node.isLeaf
          leafNodes.append(node);
        else
          leafNodes.append(node.leafNodes, true);
        end

        children.append(node);

        % rewind the key stack for our parent.  leafs don't descend and so
        % don't require a rewind.
        if ~ node.isLeaf
          forwardKeyStack.push( backwardKeyStack.pop() );
        end
      end

      self.children = children;
      self.leafNodes = leafNodes;
      self.ovationExport = epochList.ovationExport;
    end
  end

  methods
    function skpath = get.splitValues(self)
      import auimodel.Map;

      skpathMap = Map();
      self.splitKeyPathHelper(skpathMap);

      skpath = skpathMap;
    end

    function splitKeyPathHelper(self, skpathMap)
      if isobject(self.parent)
        % recursive case: there are still parents to transcend along
        self.parent.splitKeyPathHelper(skpathMap);
        skpathMap.set(self.parent.splitKey, self.splitValue);
      end
    end

    function accept(self, visitor)
      % base case: visitor only visits us
      visitor.visit(self);

      % recursive case: visitor should visit our children as well
      if ~ isempty(self.children)
        listCell = self.children.toCell();
        for i = 1 : length(listCell)
          child = listCell{i};
          child.accept(visitor);
        end
      end
    end

    % CODE DEBT: should be factored out into a general utility class 'tostr'
    % method.
    function str = get.dotEdgeLabel(self)
      import auimodel.Util;
      str = Util.tostr(self.splitValue);
    end

    function label = get.dotLabel(self)
      if self.isLeaf
        label = sprintf('[%d epochs]', self.epochList.length());
      else
        label = char(self.splitKey);
      end
    end

    function visualize(self)
      import auimodel.TreeDotBuilder;

      builder = TreeDotBuilder();
      builder.buildDot(self);
      builder.displayDiagram();
    end

    function saveTree(self, filename)
      listCell = self.leafNodes.toCell();
      for i = 1 : length(listCell)
        leaf = listCell{i};
        leaf.epochList.flush;
        leaf.epochList.disableLazyLoads;
      end

      % pseudo guid to avoid namespace collisions.
      v00bd9f99c3f4e7b42bfe6f1f5e240e77 = self;

      save(filename, 'v00bd9f99c3f4e7b42bfe6f1f5e240e77');
      
      listCell = self.leafNodes.toCell();
      for i = 1 : length(listCell)
        leaf = listCell{i};
        leaf.epochList.enableLazyLoads;
      end      
    end

    function hash = stringHash(self)
      hash = self.guid;
    end
  end

  methods(Static)
    function tree = loadTree(filename, suppliedProjRoot)
      import auimodel.ExportLoader;

      load(filename);
      tree = v00bd9f99c3f4e7b42bfe6f1f5e240e77;

      if nargin > 1
        ExportLoader.configureStores(tree.ovationExport, suppliedProjRoot);
      else
        ExportLoader.configureStores(tree.ovationExport);
      end

      listCell = tree.leafNodes.toCell();
      for i = 1 : length(listCell)
        leaf = listCell{i};
        leaf.epochList.enableLazyLoads();
      end

      clear v00bd9f99c3f4e7b42bfe6f1f5e240e77;
    end
  end
end

