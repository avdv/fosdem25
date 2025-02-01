load("@prelude//decls:common.bzl", "buck")

def _exec_platform_impl(ctx: AnalysisContext) -> list[Provider]:
    constraints = {}
    constraints.update(ctx.attrs.cpu_configuration[ConfigurationInfo].constraints)
    constraints.update(ctx.attrs.os_configuration[ConfigurationInfo].constraints)

    if ctx.attrs.local_enabled:
        constraints.update(ctx.attrs._runs_only_local[ConfigurationInfo].constraints)

    configuration = ConfigurationInfo(constraints = constraints, values = {})

    name = ctx.label.raw_target()
    exec_platform = ExecutionPlatformInfo(
        label = name,
        configuration = configuration,
        executor_config = CommandExecutorConfig(
            local_enabled = ctx.attrs.local_enabled,
            remote_enabled = ctx.attrs.remote_enabled,
            allow_cache_uploads = ctx.attrs.allow_cache_uploads,
            use_limited_hybrid = True,
            remote_execution_properties = ctx.attrs.remote_execution_properties,
            remote_execution_use_case = "buck2-default",
            remote_output_paths = "output_paths",
            remote_cache_enabled = ctx.attrs.remote_cache_enabled,
        ),
    )
    return [
        exec_platform,
        DefaultInfo(),
        PlatformInfo(label = str(name), configuration = configuration),
    ]

exec_platform = rule(
    impl = _exec_platform_impl,
    attrs = {
        "allow_cache_uploads": attrs.bool(default = True),
        "local_enabled": attrs.bool(),
        "remote_enabled": attrs.bool(default = False),
        "remote_cache_enabled": attrs.bool(default = True),
        "os_configuration": attrs.dep(
            providers = [ConfigurationInfo],
        ),
        "cpu_configuration": attrs.dep(
            providers = [ConfigurationInfo],
        ),
        "remote_execution_properties": attrs.dict(
            attrs.string(),
            attrs.one_of(attrs.string(), attrs.bool()),
            default = {},
        ),
        "_runs_only_local": attrs.default_only(attrs.dep(
            providers = [ConfigurationInfo],
            default = "config//platforms:runs_only_local",
        )),
    },
)

def _exec_platforms_impl(ctx: AnalysisContext) -> list[Provider]:
    return [
        DefaultInfo(),
        ExecutionPlatformRegistrationInfo(platforms = [p[ExecutionPlatformInfo] for p in ctx.attrs.platforms]),
    ]

exec_platforms = rule(
    impl = _exec_platforms_impl,
    attrs = {
        "platforms": attrs.list(attrs.dep(providers = [ExecutionPlatformInfo])),
    },
)
