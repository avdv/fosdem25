# HOW TO USE THIS MODULE:
#
#    load("@nix/flake.bzl", "flake")

System = enum("aarch64-linux", "x86_64-linux", "aarch64-darwin", "x86_64-darwin")

NixInfo = provider(
    fields = {
        "system": provider_field(System),
    },
)

## ---------------------------------------------------------------------------------------------------------------------
def __flake_package_impl(ctx: AnalysisContext, flake: Artifact, package: str, binary: str | None, binaries: list[str]) -> list[Provider]:
    # calls nix build path:<flake-path>#package.<arch-os>.<package>

    def get_value(constraint, value):
        idx = constraint.find(value)
        if idx >= 0:
            return constraint[idx + len(value):]
        return None

    if ctx.attrs.target_compatible_with:
        os = None
        cpu = None
        for constraint in ctx.attrs.target_compatible_with:
            v = get_value(constraint, "/os:")
            if v and os:
                fail("contradictory os constraints: {} and {}".format(v, os))
            elif v:
                os = v

            v = get_value(constraint, "/cpu:")
            if v and cpu:
                fail("contradictory cpu constraints: {} and {}".format(v, cpu))
            elif v:
                cpu = v

        if os == "macos":
            os = "darwin"
        if cpu == "arm64":
            cpu = "aarch64"
    else:
        hi = host_info()

        if hi.os.is_linux:
            os = "linux"
        elif hi.os.is_macos:
            os = "darwin"
        else:
            fail("host os not supported: {}".format(hi.os))

        if hi.arch.is_aarch64:
            cpu = "aarch64"
        elif hi.arch.is_x86_64:
            cpu = "x86_64"
        else:
            fail("host arch is not supported: {}".format(hi.arch))

    system = System("{cpu}-{os}".format(os = os, cpu = cpu))

    output = "packages." + system.value + "." + package

    out_link = ctx.actions.declare_output("out.link")
    nix_build = cmd_args([
        "env",
        "--",  # this is needed to avoid "Spawning executable `nix` failed: Failed to spawn a process"
        "nix",
        "--extra-experimental-features",
        "nix-command flakes",
        "build",
        #"--show-trace",         # for debugging
        cmd_args("--out-link", out_link.as_output()),
        cmd_args(cmd_args(flake, output, delimiter = "#"), absolute_prefix = "path:"),
    ])
    ctx.actions.run(nix_build, category = "nix_flake", local_only = True)

    run_info = []
    if binary:
        run_info.append(
            RunInfo(
                args = cmd_args(out_link, "bin", ctx.attrs.binary, delimiter = "/"),
            ),
        )

    sub_targets = {
        bin: [DefaultInfo(default_output = out_link), RunInfo(args = cmd_args(out_link, "bin", bin, delimiter = "/"))]
        for bin in binaries
    }

    return [
        DefaultInfo(
            default_output = out_link,
            sub_targets = sub_targets,
        ),
        NixInfo(system = system),
    ] + run_info

__flake_package = rule(
    impl = lambda ctx: __flake_package_impl(ctx, ctx.attrs.path, ctx.attrs.package or ctx.label.name, ctx.attrs.binary, ctx.attrs.binaries),
    attrs = {
        "binary": attrs.option(attrs.string(), default = None),
        "binaries": attrs.list(attrs.string(), default = []),
        "deps": attrs.list(attrs.dep(), default = []),
        "path": attrs.source(allow_directory = True),
        "package": attrs.option(attrs.string(), doc = "name of the flake output, defaults to label name", default = None),
    },
)

## ---------------------------------------------------------------------------------------------------------------------

flake = struct(
    package = __flake_package,
)
