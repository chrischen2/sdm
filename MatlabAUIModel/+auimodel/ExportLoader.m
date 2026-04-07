classdef ExportLoader < handle
  methods(Static)
    function isValid = isValidExport(ovationExport)
      isValid = isfield(ovationExport, 'projectRoot') ...
        && isfield(ovationExport, 'persistentStores');
    end

    function configureStores(ovationExport, suppliedProjRoot)
      import auimodel.*;

      proxy = CoreDataProxy.instance('auimodel');

      if ~ proxy.isInitialized()
        % locate myself
        root = strcat(fileparts(which('auimodel.ExportLoader')), '/');

        proxy.loadModelBundle(strcat(root, 'AUIModel.framework'));

        proxy.loadBundle(strcat(root, 'AUIProtocols.framework'));
        proxy.loadBundle(strcat(root, 'DAQFramework.framework'));

        proxy.loadPluginsAtPath(strcat(root, 'plugins'));

        proxy.performVoidStaticSelector('AUIIOController', 'initializeControllers:', {}); % {} maps to nil

        proxy.setIsInitialized();

        Epoch.register();
      end

      if nargin > 1 
        if ~ ischar(suppliedProjRoot)
          error('Supplied project root must be a character array.');
        end

        projectRootQualified = Util.trailingSlash(suppliedProjRoot);
      else
        projectRootQualified = [getenv('HOME') '/' ovationExport.projectRoot '/'];
      end

      if ~ isdir(projectRootQualified)
        error(['Cannot find project root at "' projectRootQualified '".  Please pass full path as last param.']);
      end

      storesQualified = cell(length(ovationExport.persistentStores), 1);

      for i = 1 : length(ovationExport.persistentStores)
        relative = ovationExport.persistentStores(i);
        qualified = char(strcat(projectRootQualified, relative));

        if ~ exist(qualified) == 2
          error(['Path "' qualified '" not that of a file.']);
        end

        storesQualified{i} = ['file://', qualified];
      end

      proxy.addStores(storesQualified, 'sqlite');
    end
  end
end

