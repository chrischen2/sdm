classdef Experiment < auimodel.TaggableCacheableEntity
  properties
    purpose;
    otherNotes;
    startDate;
    isStale;
  end

  methods(Static)
    function register()
      import auimodel.*

      proxy = CoreDataProxy.instance('auimodel');
      proxy.registerClass('Experiment', ...
        [TaggableCacheableEntity.recurseAttributes(), ...
        {'purpose', 'otherNotes', 'startDate'}]);
    end

    function obj = instance(objectId)
      obj = auimodel.TaggableCacheableEntity.instance(objectId, 'Experiment');
    end
  end

  methods
    function self = Experiment(entity)
      self = self@auimodel.TaggableCacheableEntity(entity);

      self.purpose = entity.purpose;
      self.otherNotes = entity.otherNotes;
      self.startDate = datevec(entity.startDate);

      self.loadKeywords();
    end

    function refresh(self)
      refresh@auimodel.KeywordTaggableEntity(self);
      self.isStale = false;
    end

    function setStale(self, status)
      self.isStale = status;
    end
  end
end

