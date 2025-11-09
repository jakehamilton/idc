let
  pins = import ./npins;

  flake-compat = import pins.flake-compat;

  ensure = value: message: if value then true else builtins.trace message false;

  hasPrefix =
    prefix: value:
    let
      trimmed = builtins.substring 0 (builtins.stringLength prefix) value;
    in
    trimmed == prefix;

  filterAttrs =
    fn: attrs:
    builtins.removeAttrs attrs (
      builtins.filter (name: !(fn name attrs.${name})) (builtins.attrNames attrs)
    );

  scan =
    input:
    let
      contents = builtins.readDir input.src;
    in
    {
      all = contents;
      files = filterAttrs (_name: value: value == "regular") contents;
      directories = filterAttrs (_name: value: value == "directory") contents;
      symlinks = filterAttrs (_name: value: value == "symlink") contents;
    };

  loaders = [
    {
      name = "nilla";
      check =
        input:
        let
          contents = scan input;
        in
        contents.files ? "nilla.nix";
      load =
        input:
        let
          value = import "${input.src}/${input.settings.target or "nilla.nix"}";

          result =
            if input.settings ? extend && input.settings.extend != { } then
              let
                customized = value.extend input.settings.extend;
              in
              customized.config // { inherit (customized) extend; }
            else
              value;
        in
        result;
    }

    {
      name = "nixpkgs";
      check =
        input:
        let
          contents = scan input;
        in
        contents.files ? "default.nix"
        && contents.directories ? "pkgs"
        && contents.directories ? "lib"
        && contents.symlinks ? ".version";
      load =
        input:
        let
        in
        import input.src input.settings;
    }

    {
      name = "flake";
      check =
        input:
        let
          contents = scan input;
        in
        contents.files ? "flake.nix";
      load =
        input:
        flake-compat.load {
          src = builtins.dirOf "${input.src}/${input.settings.target or "flake.nix"}";
          replacements = input.settings.inputs or { };
        };
    }

    {
      name = "sprinkles";
      check =
        input:
        let
          contents = scan input;
        in
        contents.files ? "default.nix"
        && hasPrefix "{ sprinkles ? {} }:\n" (builtins.readFile "${input.src}/default.nix");
      load =
        input:
        let
          value = import "${input.src}/${input.settings.target or "default.nix"}" {
            sprinkles = input.settings.sprinkles or null;
          };
        in
        if value.settings ? override && value.settings.override != { } then
          value.override value.settings.override
        else
          value;
    }

    {
      name = "legacy";
      check =
        input:
        let
          contents = scan input;
        in
        contents.files ? "default.nix";
      load =
        input:
        let
          value = import "${input.src}/${input.settings.target or "default.nix"}";
        in
        if builtins.isFunction value && input.settings ? args then value input.settings.args else value;
    }

    {
      name = "raw";
      check = _: true;
      load = input: input.src;
    }
  ];

  find =
    fn: list:
    if builtins.length list == 0 then
      null
    else if fn (builtins.head list) then
      builtins.head list
    else
      find fn (builtins.tail list);

  select =
    input:
    if input.loader == null then
      find (loader: loader.check input) loaders
    else
      find (loader: loader.name == input.loader) loaders;

  process =
    input:
    let
      loader = select input;
    in
    assert ensure (loader != null) "Could not find loader for ${input.src}";
    assert ensure (builtins.isAttrs input.settings)
      "Settings must be an attribute set, but got ${builtins.typeOf input.settings}.";
    assert ensure (
      input.loader == null || builtins.isString input.loader
    ) "Loader must be a string or null, but got ${builtins.typeOf input.loader}.";
    loader.load input;

  load =
    input:
    if builtins.isAttrs input && input ? src && (input ? settings || input ? loader) then
      process {
        inherit (input) src;
        settings = input.settings or { };
        loader = input.loader or null;
      }
    else
      process {
        inherit (input) src;
        settings = { };
        loader = null;
      };
in
load
