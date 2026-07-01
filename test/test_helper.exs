# Generation logs `Logger.info` progress; keep test output focused on failures.
Logger.configure(level: :warning)

ExUnit.start()
