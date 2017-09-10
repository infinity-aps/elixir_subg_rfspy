# SubgRfspy

Elixir SubgRfspy is a package to communicate with TI cc111x chips running the wireless packet firmware [subg_rfspy](https://github.com/ps2/subg_rfspy). Currently, the only implementation is via a UART connection, but an SPI implementation is in the works as well.

## Installation

Add `subg_rfspy` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:subg_rfspy, "~> 0.9.0"}
  ]
end
```
