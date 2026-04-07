classdef EpochList < auimodel.MapList
  properties
    stimuliStreamNames;
    responseStreamNames;
    keywords;
    isStale;
  end

  properties(Hidden)
    ovationExport;
  end

  methods
    function loadEpochBlock(self, epochURIs)
      import auimodel.*

      proxy = auimodel.CoreDataProxy.instance('auimodel');
      entities = proxy.getEntities(epochURIs, 'Epoch');

      for i = 1 : length(entities)
        epoch = Epoch(entities{i});

        for tag = epoch.keywords.elements
          inner = tag{1};
          self.keywords.add(inner);
        end

        self.append(epoch);
      end
    end

    function self = EpochList(ovationExport, suppliedProjRoot)
      import auimodel.*

      self.keywords = MapSet();

      if nargin < 1
        return;
      end

      if nargin > 1 
        if ~ ischar(suppliedProjRoot)
          error('Supplied project root must be a character array.');
        end

        projRoot = Util.trailingSlash(suppliedProjRoot);
      else
        projRoot = [getenv('HOME') '/' ovationExport.projectRoot];
      end

      if ~ isdir(projRoot)
        error(['Cannot find project root at "' projRoot '".  Please pass full path as last param.']);
      end

      ExportLoader.configureStores(ovationExport, projRoot);

      cacheDir = [projRoot '/.mlabauimodel/'];

      cacheFile = strcat(cacheDir, ovationExport.exportId, '-objcache.mat');
      cacheVarName = strcat('EL_', regexprep(ovationExport.exportId, '-', '_'));

      if exist(cacheFile) == 2
        load(cacheFile);

        self = eval(cacheVarName);
        self.enableLazyLoads();

        clear(cacheVarName);
        return;
      end

      % grab 1000 epochs per call
      epochCount = length(ovationExport.epochURIs);
      remainder = mod(epochCount, 1000);
      factors = (epochCount - remainder) / 1000;

      if factors > 0
        for f = 1 : factors
          start = (f - 1) * 1000 + 1;
          fin = f * 1000;
          self.loadEpochBlock({ovationExport.epochURIs{start : fin}});
        end
      end

      if remainder > 0
        factorsEnd = epochCount - remainder + 1;
        self.loadEpochBlock({ovationExport.epochURIs{factorsEnd : epochCount}});
      end

      self.ovationExport = ovationExport;
      self.populateStreamNames();

      if ~ isdir(cacheDir) && ~ system(['touch ' projRoot ' # cache save fail'])
        mkdir(cacheDir);
      end

      if isdir(cacheDir)
        eval([cacheVarName ' = self;';]);

        self.disableLazyLoads();

        % stored version should be flagged stale so mutable data can be refreshed
        % after cached object graph is loaded.
        self.setStale(true);
        save(cacheFile, cacheVarName);
        self.setStale(false);

        self.enableLazyLoads();
      end
    end

    function populateStreamNames(self)
      firstEpoch = self.firstValue();
      self.responseStreamNames = fields(firstEpoch.responses);
      self.stimuliStreamNames = fields(firstEpoch.stimuli);
    end

    function setStale(self, status)
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.setStale(status);
      end

      self.isStale = status;
    end

    % add user protocol settings in a batch, only saving the context at the very end.
    function setProtocolSetting(self, setting, value)
      import auimodel.CoreDataProxy;

      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.setProtocolSetting(setting, value, false);
      end

      proxy = CoreDataProxy.instance('auimodel');
      proxy.saveContext();
    end

    % retrieve stored values that are mutable in the database.  descends through
    % each epoch, etc.
    function refresh(self)
      keywords = auimodel.MapSet();

      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.refresh();
        keywords.add(epoch.keywords);
      end

      self.keywords = keywords;
      self.isStale = false;
    end

    % precondition: all responses have same duration / number of data points.
    % precondition: all epochs have a response from passed streamName.
    function matrix = dataMatrixByStreamName(self, streamType, streamName, ...
        selectedOnly)

      firstEpoch = self.firstValue();

      points = size(firstEpoch.(streamType).(streamName).data);
      points = points(2);

      matrix = zeros(self.length, points);

      i = 1;
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};

        % ??? Operands to the || and && operators must be convertible to logical
        % scalar values.
        % if selectedOnly && ~ epoch.isSelected

        if selectedOnly
          if isempty(epoch.isSelected)
            continue;
          end
        end

        thesePoints = size(epoch.(streamType).(streamName).data);
        thesePoints = thesePoints(2);

        if ~ (points == thesePoints)
          disp(sprintf(strcat('Inconsistent data length in %dth epoch ', ...
            ' (was %d, expected %d) -- terminating.'), i, thesePoints, points));
           return
        end

        matrix(i, 1 : points) = epoch.(streamType).(streamName).data;
      end
    end

    function responses = responsesByStreamName(self, streamName, selectedOnly)
      if nargin < 3
        selectedOnly = false;
      end

      responses = self.dataMatrixByStreamName('responses', streamName, ...
        selectedOnly);
    end

    % clears the cached stimulus and response data for the epochs in this
    % list.
    function flush(self)
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        self.flushDataForType(epoch, 'responses');
        self.flushDataForType(epoch, 'stimuli');
      end
    end

    function flushDataForType(self, epoch, streamType)
      streamNames = fields(epoch.(streamType));
      for i = 1 : length(streamNames)
        epoch.(streamType).(streamNames{i}).flush();
      end
    end

    function stimuli = stimuliByStreamName(self, streamName, selectedOnly)
      if nargin < 3
        selectedOnly = false;
      end

      stimuli = self.dataMatrixByStreamName('stimuli', streamName, ...
        selectedOnly);
    end

    function addKeywordTag(self, tag)
      import auimodel.CoreDataProxy;
      proxy = CoreDataProxy.instance('auimodel');

      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.addKeywordTag(tag, false);
      end

      proxy.saveContext();

      % round trip to verify persistence.
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.loadKeywords();
      end

      self.keywords.add(tag);
    end

    function removeKeywordTag(self, tag)
      import auimodel.CoreDataProxy;
      proxy = CoreDataProxy.instance('auimodel');

      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.removeKeywordTag(tag, false);
      end

      proxy.saveContext();

      self.keywords.remove(tag);
    end

    function enableLazyLoads(self)
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.enableLazyLoads;
      end
    end

    function disableLazyLoads(self)
      listCell = self.toCell();
      for i = 1 : length(listCell)
        epoch = listCell{i};
        epoch.disableLazyLoads();
      end
    end

    function newlist = sortedByEpochNumber(self)
      function order = epoch_number_cmp(epochs, i1, i2)
        en1 = epochs{i1}.protocolSettings.('acquirino:epochNumber');
        en2 = epochs{i2}.protocolSettings.('acquirino:epochNumber');

        if (en1 > en2)
          order = 1;
        elseif (en1 < en2)
          order = -1;
        else
          order = 0;
        end
      end

      epochsCell = self.toCell();
      idxs = auimodel.quicksort(epochsCell, @epoch_number_cmp);

      newlist = auimodel.EpochList();

      for i = idxs
        newlist.append(epochsCell{i});
      end

      newlist.ovationExport = self.ovationExport;
    end
  end
end

