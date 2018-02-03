defmodule Pooly.PoolsSupervisor do
  use Supervisor 

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__) #starts and gives name of Module
  end

  def init(_) do
    opts = [
      strategy: :one_for_one #one for one to pass in SUP -- one pool crash shouldn't affect another
    ]
    supervise([], opts)
  end
end