classdef Cell < auimodel.TaggableCacheableEntity
  properties
    comment;
    label;
    startDate;
    experiment;
    isStale;
  end

  methods(Static)
    function register()
      import auimodel.*
      proxy = CoreDataProxy.instance('auimodel');
      proxy.registerClass('Cell', ...
        [TaggableCacheableEntity.recurseAttributes(), ...
        {'comment', 'label', 'startDate', 'experiment', ...
         'experiment.objectID.URIRepresentation'}]);
    end

    function obj = instance(objectId)
      obj = auimodel.TaggableCacheableEntity.instance(objectId, 'Cell');
    end
  end

  methods
    function self = Cell(entity)
      self = self@auimodel.TaggableCacheableEntity(entity);

      import auimodel.*

      self.comment = entity.comment;
      self.label = entity.label;
      self.startDate = datevec(entity.startDate);

      self.experiment = Experiment.instance(entity.('experiment.objectID.URIRepresentation'));
      self.loadKeywords();
    end

    function refresh(self)
      refresh@auimodel.KeywordTaggableEntity(self);

      if self.experiment.isStale
        self.experiment.refresh();
      end

      self.isStale = false;
    end

    function setStale(self, status)
      if ~ self.experiment.isStale == status
        self.experiment.setStale(status);
      end
      self.isStale = status;
    end

    function string = toString(self)
      string = datestr(self.startDate, 'mm/dd/yy HH:MM:SS AM');
    end
  end
end

