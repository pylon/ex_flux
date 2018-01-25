use Mix.Config

config :logger, level: :warn

config :inflex, Inflex.TestDatabase,
  database: "test",
  host: "localhost",
  udp_port: 8089,
  batch_size: 5,
  max_queue_size: 100,
  flush_interval: 1
