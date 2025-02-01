load("@prelude//utils:arglike.bzl", "ArgLike")

def wrap_stdenv(actions: AnalysisActions, name: str, cmd: ArgLike, stdBash: ArgLike, env: ArgLike) -> Artifact:
    return actions.write(
        name,
        cmd_args(
            cmd_args(stdBash, format = "#! {} -e"),
            # N.B. source the given .env file and auto export any changed / added variables
            cmd_args("set -a", cmd_args(env, format = "source {}"), "set +a", delimiter = " ; "),
            cmd_args("exec", cmd, '"$@"', delimiter = " "),
        ),
        is_executable = True,
        with_inputs = True,
    )
