# CUDA {#cuda}

Compute Unified Device Architecture (CUDA) is a parallel computing platform and application programming interface (API) created by NVIDIA for GPU-accelerated computing. It's widely used for high-performance computing (HPC) and machine learning (ML) applications.

This chapter covers:
- **User Guide**: Configuring nixpkgs for CUDA, using the binary cache, and running CUDA applications
- **Contributing**: Maintaining CUDA packages, updating redistributables, and writing tests
- **Troubleshooting**: Common build and runtime issues

## User Guide {#cuda-user-guide}

Packages provided by NVIDIA which require CUDA are typically stored in CUDA package sets.

Nixpkgs provides a number of CUDA package sets, each based on a different CUDA release. Top-level attributes that provide access to CUDA package sets follow these naming conventions:

- `cudaPackages_x_y`: A major-minor-versioned package set for a specific CUDA release, where `x` and `y` are the major and minor versions of the CUDA release.
- `cudaPackages_x`: A major-versioned alias to the major-minor-versioned CUDA package set with the latest widely supported major CUDA release.
- `cudaPackages`: An unversioned alias to the major-versioned alias for the latest widely supported CUDA release. The package set referenced by this alias is also referred to as the "default" CUDA package set.

It is recommended to use the unversioned `cudaPackages` attribute. While versioned package sets are available (e.g., `cudaPackages_12_8`), they are periodically removed.

Here are two examples to illustrate the naming conventions:

- If `cudaPackages_12_9` is the latest release in the 12.x series, but core libraries like OpenCV or ONNX Runtime fail to build with it, `cudaPackages_12` may alias `cudaPackages_12_8` instead of `cudaPackages_12_9`.
- If `cudaPackages_13_1` is the latest release, but core libraries like PyTorch or Torch Vision fail to build with it, `cudaPackages` may alias `cudaPackages_12` instead of `cudaPackages_13`.

All CUDA package sets include common CUDA packages like `libcublas`, `cudnn`, `tensorrt`, and `nccl`.

### Configuring Nixpkgs for CUDA {#cuda-configuring-nixpkgs-for-cuda}

CUDA support is not enabled by default in Nixpkgs. To enable CUDA support, make sure Nixpkgs is imported with a configuration similar to the following:

```nix
{ pkgs }:
{
  allowUnfreePredicate = pkgs._cuda.lib.allowUnfreeCudaPredicate;
  cudaCapabilities = [ <target-architectures> ];
  cudaForwardCompat = true;
  cudaSupport = true;
}
```

The majority of CUDA packages are unfree, so either `allowUnfreePredicate` or `allowUnfree` should be set.

The `cudaSupport` configuration option is used by packages to conditionally enable CUDA-specific functionality. This configuration option is commonly used by packages which can be built with or without CUDA support.

The `cudaCapabilities` configuration option specifies a list of CUDA capabilities. Packages use this option to control device code generation, which affects:

- **Performance**: Architecture-specific code can leverage hardware features
- **Build time**: Fewer capabilities means faster compilation (NVCC is slow)
- **Closure size**: Device code is large; fewer targets means smaller binaries

For example, build for Ada Lovelace GPUs with `cudaCapabilities = [ "8.9" ];`. If not provided, the default is calculated per-package set based on GPUs supported by that CUDA version.

#### Understanding capability suffixes {#cuda-capability-suffixes}

CUDA capabilities identify GPU architectures and their feature sets:

- **Base capability** (e.g., `"9.0"`): Standard features for an architecture (Hopper)
- **Architecture-specific** suffix `a` (e.g., `"9.0a"`): Hardware-exclusive features, not forward-compatible via PTX
- **Family-specific** suffix `f` (e.g., `"10.0f"`): Features shared across a chip family (Blackwell)
- **Jetson capabilities** (e.g., `"8.7"`): NVIDIA's embedded devices, requires `aarch64-linux`

For the complete list of capabilities, see:

- [NVIDIA CUDA GPUs](https://developer.nvidia.com/cuda-gpus)
- [Arnon Shimoni's Architecture Guide](https://arnon.dk/matching-sm-architectures-arch-and-gencode-for-various-nvidia-cards/)
- In-tree reference: `pkgs/development/cuda-modules/_cuda/db/bootstrap/cuda.nix`

::: {.caution}
Capabilities with suffixes (`a`, `f`) and Jetson capabilities are **not built by default**. You must explicitly include them in `cudaCapabilities`.
:::

The `cudaForwardCompat` boolean configuration option determines whether PTX support for future hardware is enabled. PTX is NVIDIA's intermediate representation (similar to assembly) that can be JIT-compiled for newer GPUs at runtime. Enable this when distributing binaries that should work on future hardware; disable it when targeting architecture-specific features (e.g., `9.0a`) or to reduce binary size.

### Using the CUDA Binary Cache {#cuda-binary-cache}

Building CUDA packages from source is time-consuming. A community binary cache is available at `cache.nixos-cuda.org`.

For NixOS (`configuration.nix`):

```nix
{
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];
    trusted-public-keys = [ "cache.nixos-cuda.org-1:xFwPMlkdPPGSwQdmgSPuWlOVQ5/6BfgAQaFFBbP8PMs=" ];
  };
}
```

For non-NixOS (`~/.config/nix/nix.conf`):

```ini
extra-substituters = https://cache.nixos-cuda.org
extra-trusted-public-keys = cache.nixos-cuda.org-1:xFwPMlkdPPGSwQdmgSPuWlOVQ5/6BfgAQaFFBbP8PMs=
```

::: {.note}
The cache moved from `cuda-maintainers.cachix.org` to `cache.nixos-cuda.org` in November 2025.
:::

### Modifying CUDA package sets {#cuda-modifying-cuda-package-sets}

CUDA package sets are defined in `pkgs/top-level/cuda-packages.nix`. A CUDA package set is created by `callPackage`-ing `pkgs/development/cuda-modules/default.nix` with an attribute set `manifests`, containing NVIDIA manifests for each redistributable. The manifests for supported redistributables are available through `_cuda.manifests` and live in `pkgs/development/cuda-modules/_cuda/manifests`.

The majority of the CUDA package set tooling is available through the top-level attribute set `_cuda`, a fixed-point defined outside the CUDA package sets. As a fixed-point, `_cuda` should be modified through its `extend` attribute.

::: {.caution}
As indicated by the underscore prefix, `_cuda` is an implementation detail and no guarantees are provided with respect to its stability or API. The `_cuda` attribute set is exposed only to ease creation or modification of CUDA package sets by expert, out-of-tree users.
:::

Out-of-tree modifications of packages should use `overrideAttrs` to make any necessary modifications to the package expression.

::: {.note}
The `_cuda` attribute set previously exposed `fixups`, an attribute set mapping from package name (`pname`) to a `callPackage`-compatible expression which provided to `overrideAttrs` on the result of a generic redistributable builder. This functionality has been removed in favor of including full package expressions for each redistributable package to ensure consistent attribute set membership across supported CUDA releases, platforms, and configurations.
:::

### Extending CUDA package sets {#cuda-extending-cuda-package-sets}

CUDA package sets are scopes and provide the usual `overrideScope` attribute for overriding package attributes (see the note about `_cuda` in [Configuring CUDA package sets](#cuda-modifying-cuda-package-sets)).

Inspired by `pythonPackagesExtensions`, the `_cuda.extensions` attribute is a list of extensions applied to every version of the CUDA package set, allowing modification of all versions of the CUDA package set without needing to know their names or explicitly enumerate and modify them. As an example, disabling `cuda_compat` across all CUDA package sets can be accomplished with this overlay:

```nix
final: prev: {
  _cuda = prev._cuda.extend (
    _: prevAttrs: {
      extensions = prevAttrs.extensions ++ [ (_: _: { cuda_compat = null; }) ];
    }
  );
}
```

Redistributable packages are constructed by the `buildRedist` helper; see `pkgs/development/cuda-modules/buildRedist/default.nix` for the implementation.

### Using Legacy CUDA Versions {#cuda-legacy-versions}

CUDA versions are periodically removed from nixpkgs when their required compiler versions (GCC/Clang) are no longer maintained in nixpkgs. The [cuda-legacy](https://github.com/nixos-cuda/cuda-legacy) repository preserves these older versions as overlays.

To use cuda-legacy in a flake:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cuda-legacy.url = "github:nixos-cuda/cuda-legacy";
  };

  outputs = { nixpkgs, cuda-legacy, ... }: {
    packages.x86_64-linux.default =
      let
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ cuda-legacy.overlays.default ];
          config.allowUnfree = true;
        };
      in
      # Now you can access older CUDA versions
      pkgs.cudaPackages_11_8.cudatoolkit;
  };
}
```

cuda-legacy provides:

- Manifests for CUDA versions removed from nixpkgs
- Vendored older GCC versions (9, 10, 11) required by older CUDA releases
- The same package expressions as nixpkgs (ensuring compatibility)

::: {.warning}
cuda-legacy is provided as-is with limited maintenance guarantees. Use at your own risk.
:::

### Using `cudaPackages` {#cuda-using-cudapackages}

::: {.caution}
A non-trivial amount of CUDA package discoverability and usability relies on the various setup hooks used by a CUDA package set. As a result, users will likely encounter issues trying to perform builds within a `devShell` without manually invoking phases.
:::

To use one or more CUDA packages in an expression, give the expression a `cudaPackages` parameter, and in case CUDA support is optional, add a `config` and `cudaSupport` parameter:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages,
}:
<package-expression>
```

In your package's derivation arguments, it is _strongly_ recommended that the following are set:

```nix
{
  __structuredAttrs = true;
  strictDeps = true;
}
```

These settings ensure that the CUDA setup hooks function as intended.

When using `callPackage`, you can choose to pass in a different variant, e.g. when a package requires a specific version of CUDA:

```nix
{ mypkg = callPackage { cudaPackages = cudaPackages_12_6; }; }
```

::: {.caution}
Overriding the CUDA package set for a package may cause inconsistencies, because the override does not affect its direct or transitive dependencies. As a result, it is easy to end up with a package that uses a different CUDA package set than its dependencies. If possible, change the default CUDA package set globally to ensure a consistent environment.
:::

### Using `backendStdenv` {#cuda-using-backendstdenv}

NVCC (NVIDIA's CUDA compiler) is tightly coupled to specific versions of host compilers (GCC or Clang). Using an incompatible compiler version causes:

- Compilation failures or cryptic error messages
- Standard library parsing errors due to language feature changes
- Runtime linking issues from mismatched glibc or libstdc++ versions

`cudaPackages.backendStdenv` provides a standard environment with a compiler version compatible with the CUDA version in that package set. **Always use `backendStdenv` instead of `stdenv` when building CUDA code.**

For packages with optional CUDA support:

```nix
{
  config,
  cudaSupport ? config.cudaSupport,
  cudaPackages,
  stdenv,
}:
let
  effectiveStdenv = if cudaSupport then cudaPackages.backendStdenv else stdenv;
in
effectiveStdenv.mkDerivation {
  # ...
}
```

`backendStdenv` exposes useful attributes for build logic:

| Attribute | Description |
|-----------|-------------|
| `cudaCapabilities` | Validated list of capabilities for this CUDA version |
| `hasJetsonCudaCapability` | Whether any Jetson capability is selected |
| `hasArchitectureSpecificCudaCapability` | Whether any `a` suffix capability is selected |
| `hostRedistSystem` | NVIDIA's platform identifier (e.g., `linux-x86_64`) |

### Using `cudaPackages.flags` {#cuda-using-flags}

The `flags` attribute provides pre-formatted strings and utilities for configuring CUDA builds:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `cudaCapabilities` | List of capabilities | `["8.6" "8.9"]` |
| `cmakeCudaArchitecturesString` | Semicolon-separated for CMake | `"86;89"` |
| `gencode` | List of NVCC gencode flags | `["-gencode=arch=compute_86,code=sm_86" ...]` |
| `gencodeString` | Space-separated gencode string | For shell commands |
| `realArches` | SASS architecture identifiers | `["sm_86" "sm_89"]` |
| `virtualArches` | PTX architecture identifiers | `["compute_86" "compute_89"]` |

Example CMake usage:

```nix
cmakeFlags = [
  "-DCMAKE_CUDA_ARCHITECTURES=${cudaPackages.flags.cmakeCudaArchitecturesString}"
];
```

### NVCC Compiler Compatibility {#cuda-nvcc-compiler-compatibility}

NVCC requires specific versions of host compilers. The table below shows supported compiler ranges:

| CUDA | GCC Min | GCC Max | Clang Min | Clang Max |
|------|---------|---------|-----------|-----------|
| 12.6 | 6 | 13 | 7 | 18 |
| 12.8 | 6 | 14 | 7 | 19 |
| 12.9 | 6 | 14 | 7 | 19 |
| 13.0 | 6 | 15 | 7 | 20 |

For the complete compatibility matrix, see:

- [NVIDIA CUDA Installation Guide - Host Compiler Support](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#host-compiler-support-policy)
- In-tree reference: `pkgs/development/cuda-modules/_cuda/db/bootstrap/nvcc.nix`

::: {.note}
`backendStdenv` automatically selects a compatible compiler. This table is primarily useful for debugging compiler-related build failures.
:::

### Understanding CUDA Package Outputs {#cuda-package-outputs}

CUDA packages use multiple outputs to manage their large file sizes. Unlike typical packages, CUDA packages separate components more aggressively:

| Output | Contents | Notes |
|--------|----------|-------|
| `out` | Runtime binaries and default files | Usually what you want for running applications |
| `bin` | Executables only | |
| `dev` | CMake configs, pkg-config files | Pulls in `lib` and `include` via propagation |
| `lib` | Dynamic libraries (`.so` files) | Can be several gigabytes |
| `static` | Static libraries (`.a` files) | Often exceeds 2GB; kept separate intentionally |
| `include` | Header files | Useful when you only need headers, not binaries |
| `stubs` | Stub libraries for linking | Used when runtime libs come from driver |
| `doc` | Documentation | |
| `samples` | Example code | |
| `python` | Python bindings | |

::: {.note}
The `dev` output is selected by default when using a CUDA package as a build input. It pulls in `lib` and `include` through `propagatedBuildInputs`, so you typically don't need to specify outputs explicitly.
:::

**Why this structure?**

CUDA static libraries are enormous (a single library can exceed 2GB). Placing them in `dev` (as is conventional) would force everyone to download gigabytes of rarely-used files. By separating `static`, users only download what they need.

### Nixpkgs CUDA variants {#cuda-nixpkgs-cuda-variants}

Nixpkgs CUDA variants are provided primarily for the convenience of selecting CUDA-enabled packages by attribute path. As an example, the `pkgsForCudaArch` collection of CUDA Nixpkgs variants allows you to access an instantiation of OpenCV with CUDA support for an Ada Lovelace GPU with the attribute path `pkgsForCudaArch.sm_89.opencv`, without needing to modify the `config` provided when importing Nixpkgs.

::: {.caution}
Nixpkgs variants are not free: they require re-evaluating Nixpkgs. Where possible, import Nixpkgs once, with the desired configuration.
:::

#### Using `cudaPackages.pkgs` {#cuda-using-cudapackages-pkgs}

Each CUDA package set has a `pkgs` attribute, which is a variant of Nixpkgs in which the enclosing CUDA package set becomes the default. This was done primarily to avoid package set leakage, wherein a member of a non-default CUDA package set has a (potentially transitive) dependency on a member of the default CUDA package set.

::: {.note}
Package set leakage is a common problem in Nixpkgs and is not limited to CUDA package sets.
:::

As an added benefit of `pkgs` being configured this way, building a package with a non-default version of CUDA is as simple as accessing an attribute. As an example, `cudaPackages_12_8.pkgs.opencv` provides OpenCV built against CUDA 12.8.

#### Using `pkgsCuda` {#cuda-using-pkgscuda}

The `pkgsCuda` attribute set is a variant of Nixpkgs configured with `cudaSupport = true;` and `rocmSupport = false`. It is a convenient way to access a variant of Nixpkgs configured with the default set of CUDA capabilities.

#### Using `pkgsForCudaArch` {#cuda-using-pkgsforcudaarch}

The `pkgsForCudaArch` attribute set maps CUDA architectures (e.g., `sm_89` for Ada Lovelace or `sm_90a` for architecture-specific Hopper) to Nixpkgs variants configured to support exactly that architecture. As an example, `pkgsForCudaArch.sm_89` is a Nixpkgs variant extending `pkgs` and setting the following values in `config`:

```nix
{
  cudaSupport = true;
  cudaCapabilities = [ "8.9" ];
  cudaForwardCompat = false;
}
```

::: {.note}
In `pkgsForCudaArch`, the `cudaForwardCompat` option is set to `false` because exactly one CUDA architecture is supported by the corresponding Nixpkgs variant. Furthermore, some architectures, including architecture-specific feature sets like `sm_90a`, cannot be built with forward compatibility.
:::

::: {.caution}
Not every version of CUDA supports every architecture!

To illustrate: support for Blackwell (e.g., `sm_100`) was added in CUDA 12.8. Assume our Nixpkgs' default CUDA package set is to CUDA 12.6. Then the Nixpkgs variant available through `pkgsForCudaArch.sm_100` is useless, since packages like `pkgsForCudaArch.sm_100.opencv` and `pkgsForCudaArch.sm_100.python3Packages.torch` will try to generate code for `sm_100`, an architecture unknown to CUDA 12.6. In that case, you should use `pkgsForCudaArch.sm_100.cudaPackages_12_8.pkgs` instead (see [Using `cudaPackages.pkgs`](#cuda-using-cudapackages-pkgs) for more details).
:::

The `pkgsForCudaArch` attribute set makes it possible to access packages built for a specific architecture without needing to manually call `pkgs.extend` and supply a new `config`. As an example, `pkgsForCudaArch.sm_89.python3Packages.torch` provides PyTorch built for Ada Lovelace GPUs.

### Running Docker or Podman containers with CUDA support {#cuda-docker-podman}

It is possible to run Docker or Podman containers with CUDA support. The recommended mechanism to perform this task is to use the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/index.html).

The NVIDIA Container Toolkit can be enabled in NixOS like follows:

```nix
{ hardware.nvidia-container-toolkit.enable = true; }
```

This will automatically enable a service that generates a CDI specification (located at `/var/run/cdi/nvidia-container-toolkit.json`) based on the auto-detected hardware of your machine. You can check this service by running:

```ShellSession
$ systemctl status nvidia-container-toolkit-cdi-generator.service
```

::: {.note}
Depending on what settings you had already enabled in your system, you might need to restart your machine in order for the NVIDIA Container Toolkit to generate a valid CDI specification for your machine.
:::

Once that a valid CDI specification has been generated for your machine on boot time, both Podman and Docker (> 25) will use this spec if you provide them with the `--device` flag:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

```ShellSession
$ docker run --rm -it --device=nvidia.com/gpu=all ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

You can check all the identifiers that have been generated for your auto-detected hardware by checking the contents of the `/var/run/cdi/nvidia-container-toolkit.json` file:

```ShellSession
$ nix run nixpkgs#jq -- -r '.devices[].name' < /var/run/cdi/nvidia-container-toolkit.json
0
1
all
```

#### Specifying what devices to expose to the container {#cuda-specifying-what-devices-to-expose-to-the-container}

You can choose what devices are exposed to your containers by using the identifier on the generated CDI specification. Like follows:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
```

You can repeat the `--device` argument as many times as necessary if you have multiple GPU's and you want to pick up which ones to expose to the container:

```ShellSession
$ podman run --rm -it --device=nvidia.com/gpu=0 --device=nvidia.com/gpu=1 ubuntu:latest nvidia-smi -L
GPU 0: NVIDIA GeForce RTX 4090 (UUID: <REDACTED>)
GPU 1: NVIDIA GeForce RTX 2080 SUPER (UUID: <REDACTED>)
```

::: {.note}
By default, the NVIDIA Container Toolkit will use the GPU index to identify specific devices. You can change the way to identify what devices to expose by using the `hardware.nvidia-container-toolkit.device-name-strategy` NixOS attribute.
:::

#### Using docker-compose {#cuda-using-docker-compose}

It's possible to expose GPUs to a `docker-compose` environment as well. With a `docker-compose.yaml` file like follows:

```yaml
services:
  some-service:
    image: ubuntu:latest
    command: sleep infinity
    deploy:
      resources:
        reservations:
          devices:
          - driver: cdi
            device_ids:
            - nvidia.com/gpu=all
```

In the same manner, you can pick specific devices that will be exposed to the container:

```yaml
services:
  some-service:
    image: ubuntu:latest
    command: sleep infinity
    deploy:
      resources:
        reservations:
          devices:
          - driver: cdi
            device_ids:
            - nvidia.com/gpu=0
            - nvidia.com/gpu=1
```

## Contributing {#cuda-contributing}

::: {.warning}
This section of the docs is still very much in progress. Feedback is welcome in GitHub Issues tagging @NixOS/cuda-maintainers or on [Matrix](https://matrix.to/#/#cuda:nixos.org).
:::

### Package set maintenance {#cuda-package-set-maintenance}

The CUDA Toolkit is a suite of CUDA libraries and software meant to provide a development environment for CUDA-accelerated applications. Until the release of CUDA 11.4, NVIDIA had only made the CUDA Toolkit available as a multi-gigabyte runfile installer. From CUDA 11.4 and onwards, NVIDIA has also provided CUDA redistributables (“CUDA-redist”): individually packaged CUDA Toolkit components meant to facilitate redistribution and inclusion in downstream projects. These packages are available in the [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) package set.

While the monolithic CUDA Toolkit runfile installer is no longer provided, [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit) provides a `symlinkJoin`-ed approximation of common libraries. The use of [`cudaPackages.cudatoolkit`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages.cudatoolkit) is discouraged: all new projects should use the CUDA redistributables available in [`cudaPackages`](https://search.nixos.org/packages?channel=unstable&type=packages&query=cudaPackages) instead, as they are much easier to maintain and update.

#### Updating redistributables {#cuda-updating-redistributables}

Whenever a new version of a redistributable manifest is made available:

1. Check the corresponding README.md in `pkgs/development/cuda-modules/_cuda/manifests` for the URL to use when vendoring manifests.
2. Update the manifest version used in construction of each CUDA package set in `pkgs/top-level/cuda-packages.nix`.
3. Update package expressions in `pkgs/development/cuda-modules/packages`.

Updating package expressions amounts to:

- adding fixes conditioned on newer releases, like added or removed dependencies
- adding package expressions for new packages
- updating `passthru.brokenConditions` and `passthru.badPlatformsConditions` with various constraints, (e.g., new releases removing support for various architectures)

#### Updating supported compilers and GPUs {#cuda-updating-supported-compilers-and-gpus}

1. Update `nvccCompatibilities` in `pkgs/development/cuda-modules/_cuda/db/bootstrap/nvcc.nix` to include the newest release of NVCC, as well as any newly supported host compilers.
2. Update `cudaCapabilityToInfo` in `pkgs/development/cuda-modules/_cuda/db/bootstrap/cuda.nix` to include any new GPUs supported by the new release of CUDA.

#### Updating the CUDA package set {#cuda-updating-the-cuda-package-set}

::: {.note}
Changing the default CUDA package set should occur in a separate PR, allowing time for additional testing.
:::

::: {.warning}
As described in [Using `cudaPackages.pkgs`](#cuda-using-cudapackages-pkgs), the current implementation fix for package set leakage involves creating a new instance for each non-default CUDA package sets. As such, We should limit the number of CUDA package sets which have `recurseForDerivations` set to true: `lib.recurseIntoAttrs` should only be applied to the default CUDA package set.
:::

1. Include a new `cudaPackages_<major>_<minor>` package set in `pkgs/top-level/cuda-packages.nix` and inherit it in `pkgs/top-level/all-packages.nix`.
2. Successfully build the closure of the new package set, updating expressions in `pkgs/development/cuda-modules/packages` as needed. Below are some common failures:

| Unable to ...  | During ...                       | Reason                                           | Solution                   | Note                                                         |
| -------------- | -------------------------------- | ------------------------------------------------ | -------------------------- | ------------------------------------------------------------ |
| Find headers   | `configurePhase` or `buildPhase` | Missing dependency on a `dev` output             | Add the missing dependency | The `dev` output typically contains the headers               |
| Find libraries | `configurePhase`                 | Missing dependency on a `dev` output             | Add the missing dependency | The `dev` output typically contains CMake configuration files |
| Find libraries | `buildPhase` or `patchelf`       | Missing dependency on a `lib` or `static` output | Add the missing dependency | The `lib` or `static` output typically contains the libraries |

#### Debugging with Test Utilities {#cuda-test-utilities}

Two utility derivations help debug CUDA package issues:

- **`cudaPackages.tests.redists-unpacked`**: All redistributable sources unpacked and joined. Shows raw NVIDIA tarball contents before nixpkgs processing. Useful for finding which package contains a specific file.

- **`cudaPackages.tests.redists-installed`**: All redistributable outputs joined after installation. Shows where files end up after processing. Useful for verifying output placement.

Example usage:

```bash
# See what's in the raw NVIDIA archives
nix build .#cudaPackages.tests.redists-unpacked
find result/ -name "libcudnn*"

# See where files end up after installation
nix build .#cudaPackages.tests.redists-installed
ls result/lib/
```

Failure to run the resulting binary is typically the most challenging to diagnose, as it may involve a combination of the aforementioned issues. This type of failure typically occurs when a library attempts to load or open a library it depends on that it does not declare in its `DT_NEEDED` section. Try the following debugging steps:

1. First ensure that dependencies are patched with [`autoAddDriverRunpath`](https://search.nixos.org/packages?channel=unstable&type=packages&query=autoAddDriverRunpath).
2. Failing that, try running the application with [`nixGL`](https://github.com/guibou/nixGL) or a similar wrapper tool.
3. If that works, it likely means that the application is attempting to load a library that is not in the `RPATH` or `RUNPATH` of the binary.

### Writing tests {#cuda-writing-tests}

::: {.caution}
The existence of `passthru.testers` and `passthru.tests` should be considered an implementation detail -- they are not meant to be a public or stable interface.
:::

In general, there are two attribute sets in `passthru` that are used to build and run tests for CUDA packages: `passthru.testers` and `passthru.tests`. Each attribute set may contain an attribute set named `cuda`, which contains CUDA-specific derivations. The `cuda` attribute set is used to separate CUDA-specific derivations from those which support multiple implementations (e.g., OpenCL, ROCm, etc.) or have different licenses. For an example of such generic derivations, see the `magma` package.

::: {.note}
Derivations are nested under the `cuda` attribute due to an OfBorg quirk: if evaluation fails (e.g., because of unfree licenses), the entire enclosing attribute set is discarded. This prevents other attributes in the set from being discovered, evaluated, or built.
:::

#### `passthru.testers` {#cuda-passthru-testers}

Attributes added to `passthru.testers` are derivations which produce an executable which runs a test. The produced executable should:

- Take care to set up the environment, make temporary directories, and so on.
- Be registered as the derivation's `meta.mainProgram` so that it can be run directly.

::: {.note}
Testers which always require CUDA should be placed in `passthru.testers.cuda`, while those which are generic should be placed in `passthru.testers`.
:::

The `passthru.testers` attribute set allows running tests outside the Nix sandbox. There are a number of reasons why this is useful, since such a test:

- Can be run on non-NixOS systems, when wrapped with utilities like `nixGL` or `nix-gl-host`.
- Has network access patterns which are difficult or impossible to sandbox.
- Is free to produce output which is not deterministic, such as timing information.

#### `passthru.tests` {#cuda-passthru-tests}

Attributes added to `passthru.tests` are derivations which run tests inside the Nix sandbox. Tests should:

- Use the executables produced by `passthru.testers`, where possible, to avoid duplication of test logic.
- Include `requiredSystemFeatures = [ "cuda" ];`, possibly conditioned on the value of `cudaSupport` if they are generic, to ensure that they are only run on systems exposing a CUDA-capable GPU.

::: {.note}
Tests which always require CUDA should be placed in `passthru.tests.cuda`, while those which are generic should be placed in `passthru.tests`.
:::

This is useful for tests which are deterministic (e.g., checking exit codes) and which can be provided with all necessary resources in the sandbox.

## Troubleshooting {#cuda-troubleshooting}

### Common Build Issues

**"GLIBCXX_* not found" or similar linker errors**

You're likely mixing compiler versions. Ensure all CUDA-dependent packages use `cudaPackages.backendStdenv` instead of `stdenv`. See [Using `backendStdenv`](#cuda-using-backendstdenv).

**Can't find CUDA headers or libraries during build**

Check that:
1. The package is in `buildInputs` or `nativeBuildInputs` (depending on whether it's used at build or runtime)
2. You're using the correct output (`dev` for headers/CMake files, `lib` for libraries)
3. `strictDeps = true;` and `__structuredAttrs = true;` are set in your derivation

**CMake can't find CUDA**

Use the `flags` helper to set the architecture string:
```nix
cmakeFlags = [
  "-DCMAKE_CUDA_ARCHITECTURES=${cudaPackages.flags.cmakeCudaArchitecturesString}"
];
```

### Common Runtime Issues

**Library not found despite being in dependencies**

NVIDIA libraries frequently use `dlopen` to load dependencies at runtime rather than declaring them in `DT_NEEDED`. These won't be automatically found. Try:

1. Ensure `autoAddDriverRunpath` hook is applied to the package
2. Run with [`nixGL`](https://github.com/guibou/nixGL) or similar wrapper
3. Use `strace` to identify what's being dlopen'd:
   ```bash
   strace -e openat ./your-program 2>&1 | grep -E '\.(so|dylib)'
   ```

**"CUDA driver version is insufficient"**

Your system's NVIDIA driver is older than required by the CUDA toolkit version. Either:
- Update your NVIDIA driver
- Use an older CUDA package set (e.g., `cudaPackages_12_6` instead of `cudaPackages_13_0`)

**Build works but crashes at runtime**

Version mismatches between CUDA libraries (cuDNN, TensorRT, cuBLAS) can cause runtime failures even when builds succeed. NVIDIA's documented compatibility matrices are not always accurate. Ensure all CUDA libraries come from the same package set.

**"Unsupported GPU" or "no kernel image available"**

Your GPU's compute capability isn't in `config.cudaCapabilities`. Add it:
```nix
{
  config.cudaCapabilities = [ "8.9" ];  # For RTX 40xx
}
```

For architecture-specific capabilities (like `9.0a`), you must explicitly request them as they're not built by default.

### Getting Help

- File issues at [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs/issues) tagging `@NixOS/cuda-maintainers`
- Join the discussion on [Matrix #cuda:nixos.org](https://matrix.to/#/#cuda:nixos.org)
