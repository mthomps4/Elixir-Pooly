defmodule Pooly.Server do
  use GenServer
  import Supervisor.Spec

  #######
  # API #
  #######

  def start_link(pools_config) do
    GenServer.start_link(__MODULE__, pools_config, name: __MODULE__)
  end

  def checkout(pool_name, block, timeout) do
    Pooly.PoolServer.checkout(pool_name, block, timeout)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.PoolServer.checkin(pool_name, worker_pid)
  end

  def transaction(pool_name, fun, timeout) do
    worker = checkout(pool_name, true, timeout)
    try do
      fun.(worker)
    after
      checkin(pool_name, worker)
    end
  end

  def status(pool_name) do
    Pooly.PoolServer.status(pool_name)
  end

  #############
  # Callbacks #
  #############

  def init(pools_config) do
    pools_config |> Enum.each(fn(pool_config) ->
      send(self, {:start_pool, pool_config})
    end)

    {:ok, pools_config}
  end

  def handle_info({:start_pool, pool_config}, state) do
    {:ok, _pool_sup} = Supervisor.start_child(Pooly.PoolsSupervisor, supervisor_spec(pool_config))

    {:noreply, state}
  end

  #####################
  # Private Functions #
  #####################

  defp supervisor_spec(pool_config) do
    # TODO: WHAT SHOULD BE GOOD VALUES
    # NOTE: This needs to be random because by de
    opts = [id: :"#{pool_config[:name]}Supervisor"]
    supervisor(Pooly.PoolSupervisor, [pool_config], opts)
  end
end # End Module

####NOTES: 
# Two "flavors" of Supervisor.start_child
# {:ok, sup} = Supervisor.start_child(sup, supervisor_spec(mfa))
# OR
# {:ok, sup} = Supervisor.start_child(sup, [[]])
# Pooly.WorkerSupervisor uses a :simple_one_for_one restart
# This means the child specification has already been predefined, -- use second 
# The second version lets you pass additional arguments to the worker. 
# Under the hood the list of child specifications when creating Pooly.WorkerSupervisor
# are concatenated on the list passed in to Supervisor.start_child and the result is then passed to the worker
# The return result of new_worker/2 is the pid of the new worker. It hasn't been checked "in/out"
#
# defp new_worker(sup) do
#   {:ok, worker} = Supervisor.start_child(sup, [[]]) #dynamically creates a worker and attatches it to the SUP
#   worker
# end

#### Erlang Term Storage
# NOTES: 
# VERY efficient in-memory DB built to store Erlang/Elixir data. 
# Data access is also done in constant time
# you create a table using `:ets.new/2` 
# table name and list of opts
# iex> :ets.new(:tablename, [])
# >12308 
# returns table ID 
# The process that created ETS is the owner -- in this case iex

## ETS Table Types 
# :set -- default. Unordered, each uniq key mapping to element 
# :ordered_set -- A sorted version of :set
# :bag -- Rows with the same keys are allowed, but rows must be different
# :duplicate_bag -- Same as :bag but without row-uniqueness restriction 

# iex> :ets.new(:tablename, [:set])

## Access Rights 
# :protected -- the owner process has full read/write other process can only read -- DEFAULT
# :public -- There are no restrictions 
# :private -- only the owner can read/write 

# iex> :ets.new(:tablename, [:set, :private])

## Named tables 
# You need to supply the :named_table flag to reference the table by the atom given 
# iex> :ets.new(:tablename, [:set, :private, :named_table])

# :ets.insert(:tablename, {"key", info, info, info})
# :ets.tab2list(:tablename) --> dump of table to list 
# :ets.delete(:tablename, "key")
# :ets.lookup(:tablename, "key")
# :ets.match(:tablename, {:"$1", "infotomatch", :"$2"}) #wildcards by number of order to try and match

