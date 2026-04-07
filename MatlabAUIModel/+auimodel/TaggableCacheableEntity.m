classdef TaggableCacheableEntity < auimodel.KeywordTaggableEntity
  properties(Hidden)
    isFromCache;
  end

  methods(Static)
    function attrs = recurseAttributes(self)
      import auimodel.*;
      attrs = KeywordTaggableEntity.recurseAttributes();
    end

    function clearCache()
      persistent objectCache;
      objectCache = [];
    end

    function obj = instance(objectId, clazz)
      import containers.Map;

      persistent objectCache;
      if isempty(objectCache)
        objectCache = Map();
      end

      if objectCache.isKey(objectId)
        obj = objectCache(objectId);
        obj.isFromCache = true;
      else
        import auimodel.*
        proxy = CoreDataProxy.instance('auimodel');
        entity = proxy.getEntity(objectId);
        obj = eval([clazz '(entity)']);
        objectCache(objectId) = obj;
        obj.isFromCache = false;
      end
    end
  end

  methods
    function self = TaggableCacheableEntity(entity)
      self = self@auimodel.KeywordTaggableEntity(entity);
    end
  end
end

