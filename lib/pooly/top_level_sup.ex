defmodule Pooly.Supervisor do
  use Supervisor 

  def start_link(pool_config) do
    Supervisor.start_link(__MODULE__, pool_config)
  end

  def init(pool_config) do
    children = [
      worker(Pooly.Server, [self(), pool_config])
    ]
    opts = [strategy: :one_for_all] # Make sure to kill all and restart -- Maintain state between Sup and Worker Sup
    supervise(children, opts)
  end
end