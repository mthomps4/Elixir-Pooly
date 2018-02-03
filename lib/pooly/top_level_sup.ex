defmodule Pooly.Supervisor do
  use Supervisor 

  def start_link(pools_config) do
    Supervisor.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def init(pools_config) do
    children = [
      supervisor(Pooly.PoolsSupervisor, []),
      worker(Pooly.Server, [pools_config]) # no longer takes pid -- has name in config
    ]
    opts = [strategy: :one_for_all] # Make sure to kill all and restart -- Maintain state between Sup and Worker Sup
    supervise(children, opts)
  end
end