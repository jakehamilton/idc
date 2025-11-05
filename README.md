# `idc`

> Import Nix projects regardless of how they are exposed.

`idc` supports all of the following frameworks/libraries:

- [Nilla](https://nilla.dev)
- [Sprinkles](https://git.afnix.fr/sprinkles/sprinkles)
- [Flakes](https://wiki.nixos.org/wiki/Flakes) (with input overriding)
- Nixpkgs (special cased to **not** import as a flake)
- Plain `default.nix` files

## Install

Using `idc` is easy. Fetch it from this repository or even copy
[`./default.nix`](./default.nix) to your project as `idc.nix`, then
import `idc`.

```nix
let
    idc = builtins.fetchTarball "https://github.com/jakehamilton/idc/archive/main.tar.gz";

    # Or use a local copy
    # idc = ./idc.nix;
in
# ...
```

## Usage

To use `idc`, call the function with an attribute set containing:

| Attribute Name | Type                    | Description                                                                                                                |
| -------------- | ----------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `src`          | `Path \| Derivation`    | The source that you will be importing from.                                                                                |
| `loader`       | `Optional String`       | Manually set the loader to use (see [#loaders]). If left unset or set to `null`, `idc` will automatically select a loader. |
| `settings`     | `Optional AttributeSet` | Settings to pass to the loader (see [#loaders]).                                                                           |

```nix
# Import Nixpkgs
idc { src = my-nixpkgs; }
```

```nix
# Import a `default.nix` file, but call the function with arguments
idc {
    src = my-legacy;
    settings = {
        args = {
            system = "x86_64-linux";
        };
    };
}
```

```nix
# Import a flake, but override its nixpkgs input
idc {
    src = my-flake;
    settings = {
        inputs = {
            nixpkgs = my-nixpkgs;
        };
    };
}
```

```nix
# Import a Nilla project, but modify its configuration
idc {
    src = my-nilla;
    settings = {
        extend = {
            my-value.enable = true;
        };
    };
}
```

```nix
# Import a Sprinkle, but override it
idc {
    src = my-sprinkle;
    settings = {
        override = {
            my-value.enable = true;
        };
    };
}
```

## Loaders

A loader is a function which takes a source path and produces a useful value
from it. Typically this means that a loader will do `builtins.import src`,
but additional logic is common to support configuration of how an input is
loaded. To use a loader, set `loader` when calling `idc`. Optionally, you may
also set `settings` to customize how source is loaded.

### Legacy

**Name:** `legacy`

This loader is useful for loading `default.nix` files or any other `*.nix`
file directly.

The following settings attributes can be set on the `settings` attribute set
to customize functionality.

| Attribute Name | Type              | Description                                                                                                                                                                                       |
| -------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `target`       | `Optional String` | The file to import in the source. This defaults to `default.nix`                                                                                                                                  |
| `args`         | `Optional Any`    | It is common for `default.nix` files to export a function which takes an attribute set as its argument. When setting `args`, `idc` will automatically call this function with the value provided. |

```nix
idc {
    src = my-source;
    loader = "legacy";
    settings = {
        # Choose a different file to import in the source.
        target = "subdir/other.nix";

        # When the imported value is a function, call it with this argument.
        args = {
            x = 1;
            y = 2;
            z = 3;
        };
    };
}
```

### Nixpkgs (`default.nix`)

**Name:** `nixpkgs`

This loader is useful for loading Nixpkgs via its `default.nix` file rather
than its Flake (which `idc` typically prefers).

The value of `settings` is used when importing Nixpkgs.

```nix
idc {
    src = my-source;
    loader = "nixpkgs";
    settings = {
        # Any configuration for Nixpkgs can be used here.
        system = "x86_64-linux";

        overlays = [
            # ...
        ];

        config = {
            # ...
        };
    };
}
```

### Flakes

**Name:** `flake`

This loader is useful for loading `flake.nix` files. Notably, you can choose
to replace a Flake's inputs if desired.

The following settings attributes can be set on the `settings` attribute set
to customize functionality.

| Attribute Name | Type                    | Description                                                                                     |
| -------------- | ----------------------- | ----------------------------------------------------------------------------------------------- |
| `target`       | `Optional String`       | The file to import in the source. This defaults to `flake.nix` and **MUST** end in `flake.nix`. |
| `inputs`       | `Optional AttributeSet` | A set of inputs to use instead of the ones that are provided by the Flake.                      |

```nix
idc {
    src = my-source;
    loader = "flake";
    settings = {
        # Choose a different flake location to import in the source.
        target = "subdir/flake.nix";

        inputs = {
            # Replace only the my-helper input. Typically you will get the
            # value to use (`my-helper-flake`) by calling `idc` to import
            # that flake for use.
            my-helper = my-helper-flake;
        };
    };
}
```

### Nilla

**Name:** `nilla`

This loader is useful for loading `nilla.nix` files.

The following settings attributes can be set on the `settings` attribute set
to customize functionality.

| Attribute Name | Type                    | Description                                                        |
| -------------- | ----------------------- | ------------------------------------------------------------------ |
| `target`       | `Optional String`       | The file to import in the source. This defaults to `nilla.nix`.    |
| `extend`       | `Optional AttributeSet` | Extend the Nilla project's configuration with the provided module. |

```nix
idc {
    src = my-source;
    loader = "flake";
    settings = {
        # Choose a different file to import in the source.
        target = "subdir/nilla.nix";

        # Call `project.extend` on the imported Nilla project using the
        # value provided.
        extend = {
            # Any config option can be set for the Nilla project here.
            my-value.enable = true;
        };

        # Note that `extend` can also be a function module.
        # extend = { config }: { /* ... */ }
    };
}
```

### Sprinkles

**Name:** `sprinkles`

This loader is useful for loading `default.nix` files that use Sprinkles.

The following settings attributes can be set on the `settings` attribute set
to customize functionality.

| Attribute Name | Type                    | Description                                                       |
| -------------- | ----------------------- | ----------------------------------------------------------------- |
| `target`       | `Optional String`       | The file to import in the source. This defaults to `default.nix`. |
| `override`     | `Optional AttributeSet` | Override a Sprinkle using the provided value.                     |

```nix
idc {
    src = my-source;
    loader = "sprinkles";
    settings = {
        # Choose a different file to import in the source.
        target = "subdir/default.nix";

        # Call `sprinkle.override` on the imported Sprinkle using the
        # value provided.
        override = {
            # Any config option can be set for the Nilla project here.
            my-value.enable = true;
        };
    };
}
```

### Raw

**Name:** `raw`

This loader is a fallback which returns the source directly without
importing it. Typically this will not be used, but exists for niche
use cases or for debugging purposes.

No settings are available for this loader.

```nix
idc {
    src = my-source;
    loader = "raw";
}
```

## What does idc stand for?

**I** **D**on't **C**are, as in "I don't care what Nix library or framework
this project is using, just import it."
