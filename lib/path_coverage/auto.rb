require_relative 'kernel'

# Required by RUBYOPT=-rpath_coverage/auto, to cover a run
# with no change to its code, its settings all in ENV.
PathCoverage.start_from_env(ENV)
