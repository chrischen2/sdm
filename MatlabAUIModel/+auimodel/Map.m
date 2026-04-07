% small wrapper around containers.Map that allows for keys of arbitrary type
% by converting them into unique string representations, or "string hashes."
% also provides a more useful "display" method.  also contains a secondary
% map for keying by numeric values.
classdef Map < handle
  properties(Hidden)
    containersMapChar;
    containersMapNum;
  end

  methods
    function self = Map()
      self.containersMapChar = containers.Map();
      self.containersMapNum = containers.Map(-1, auimodel.Null);
      self.containersMapNum.remove(-1);
    end

    function key = hash(self, value)
      if isempty(value)
        MException('AUIModel:UnsupportedOperation', ['Map keys must be non-empty.']).throw();
      end

      if ischar(value)
        key = value;
      elseif isobject(value)
        % optimize for this case as it's the most common
        if strcmp(class(value), 'auimodel.Null')
            key = '[null]';
        else
          % not sure how to check for a method, but this throws w/o, which is
          % fine.
          key = value.stringHash();
        end
      elseif strcmp(class(value), 'function_handle') %GWS 5/4/09
        key = func2str(value);
      elseif isnumeric(value)
        key = num2str(value);
      else
        disp(value);
        MException('AUIModel:UnsupportedOperation', ...
          ['Do not know how to string hash preceding value.']).throw();
      end
    end

    % CODE DEBT: overriding property setters with something having different
    % semanics...  may cause weird behavior someplace.
    function set(self, key, value)
      if isnumeric(key) && length(key) == 1
        self.containersMapNum(key) = value;
      else
        stringKey = self.hash(key);
        self.containersMapChar(stringKey) = struct('key', key, 'value', value);
      end
    end

    function value = get(self, key)
      value = [];

      if isnumeric(key) && length(key) == 1
        value = self.containersMapNum(double(key));
      else
        stringKey = self.hash(key);
        if self.containersMapChar.isKey(stringKey)
          value = self.containersMapChar(stringKey).value;
        end
      end
    end

    function result = hasKey(self, key)
      if isnumeric(key) && length(key) == 1
        result = self.containersMapNum.isKey(double(key));
      else
        stringKey = self.hash(key);
        result = self.containersMapChar.isKey(stringKey);
      end
    end

    function values = values(self)
      values = cell(1, self.containersMapChar.length());

      pairs = self.containersMapChar.values();
      i = 1;
      while i <= length(pairs)
        values{i} = pairs{i}.value;
        i = i + 1;
      end

      scalars = self.containersMapNum.values();

      if isempty(pairs)
        values = scalars;
      else
        values = [values scalars];
      end
    end

    function keys = keys(self)
      keys = cell(1, self.containersMapChar.length());

      pairs = self.containersMapChar.values();
      i = 1;
      while i <= length(pairs)
        keys{i} = pairs{1, i}.key;
        i = i + 1;
      end

      numericKeys = self.containersMapNum.keys();

      if isempty(pairs)
        keys = numericKeys;
      else
        keys = [keys numericKeys];
      end
    end

    function keyCount = count(self)
      keyCount = self.containersMapChar.length() + self.containersMapNum.length();
    end

    function display(self)
      import auimodel.Util;

      display(sprintf('\nmap =\n'));

      keys = self.keys();
      if ~ isempty(keys)
        i = 1;

        while i <= length(keys)
          k = keys{i};

          keyStr = Util.tostr(k);
          valueStr = Util.tostr(self.get(k));

          keyStrSize = size(keyStr);
          valueStrSize = size(valueStr);

          if keyStrSize(1) > 1
            keyStr = transpose(keyStr);
          elseif valueStrSize(1) > 1
            valueStr = transpose(valueStr);
          end

          display(['    ' keyStr ': ' valueStr]);
          i = i + 1;
        end

        display(' ');
      else
        display(sprintf('[empty]\n'));
      end
    end
  end
end

