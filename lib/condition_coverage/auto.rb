require_relative 'kernel'

# Required by RUBYOPT=-rcondition_coverage/auto, to cover a run
# with no change to its code, its settings all in ENV.
ConditionCoverage.start_from_env(ENV)
