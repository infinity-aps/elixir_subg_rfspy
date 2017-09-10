use Mix.Config

config :logger, level: :info
config :subg_rfspy, :serial_driver, SubgRfspy.UARTProxy
