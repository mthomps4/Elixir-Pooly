defmodule Pooly.Server do
  use GenServer
  import Supervisor.Spec

  # Struct that maintaines state of Server
  defmodule State do
    defstruct sup: nil, worker_sup: nil, monitors: nil, size: nil, workers: nil, mfa: nil
  end

  #####
  #API#
  #####

  def start_link(sup, pool_config) do
    GenServer.start_link(__MODULE__, [sup, pool_config], name: __MODULE__)
  end

  def checkout do
    GenServer.call(__MODULE__, :checkout)
  end

  def checkin(worker_pid) do
    GenServer.call(__MODULE__, {:checkin, worker_pid})
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  ###########
  #CALLBACKS#
  ###########

  # Invoked when GenServer.start_link/3 is called 
  def init([sup, pool_config]) when is_pid(sup) do
    Process.flag(:trap_exit, true) # Trap exit if worker crashes 
    monitors = :ets.new(:monitors, [:private])
    init(pool_config, %State{sup: sup, monitors: monitors})
  end
  # Pattern match for the mfa option, stores it in the server's state
  def init([{:mfa, mfa}|rest], state) do
    init(rest, %{state|mfa: mfa})
  end
  # Pattern match for size option, stores in server state
  def init([{:size, size}|rest], state) do
    init(rest, %{state|size: size})
  end
  # Ignores all other options
  def init([_opts|rest], state) do
    init(rest, state)
  end
  # Base case when options list is empty 
  def init([], state) do
    send(self, :start_worker_supervisor) # sends a message to start worker sup
    {:ok, state}
  end

  ## Handles 
  def handle_info(:start_worker_supervisor, state = %{sup: sup, mfa: mfa, size: size}) do
    {:ok, worker_sup} = Supervisor.start_child(sup, supervisor_spec(mfa)) #supervisor_spec(mfa) starts the worker Sup via top-level SUP
    workers = prepopulate(size, worker_sup) # create "size" number of workers that are supervised with the newly created worker SUP
    {:noreply, %{state | worker_sup: worker_sup, workers: workers}} # updates the state with the worker Sup Pid and it's workers
  end

  # handle when consumer process :DOWN 
  # When a consumer process goes down, you match the reference in the monitors ETS table, delete the monitor, and add the worker back into state
  def handle_info({:DOWN, ref, _, _, _}, state = %{monitors: monitors, workers: workers}) do
    case :ets.match(monitors, {:"$1", ref}) do
      [[pid]] -> 
        true = :ets.delete(monitors, pid)
        new_state = %{state | workers: [pid|workers]} #returns the worker to the pool
        {:noreply, new_state}
      [[]] -> 
        {:noreply, state}
    end
  end

  # When a worker dies -- take it out return to state -- create new worker
  def handle_info({:EXIT, pid, _reason}, state = %{monitors: monitors, workers: workers, worker_sup: worker_sup}) do
    case :ets.lookup(monitors, pid) do
      [{pid, ref}] -> 
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid) 
        new_state = %{state | workers: [new_worker(worker_sup)|workers]}
      [[]] -> 
        {:noreply, state}
    end
  end

  # from = {client_pid, tag_reference}
  def handle_call(:checkout, {from_pid, _ref}, %{workers: workers, monitors: monitors} = state) do
   case workers do #where there are still workers to checkout 
    [worker|rest] -> 
      ref = Process.monitor(from_pid) # gets the server process to monitor the client process
      true = :ets.insert(monitors, {worker, ref}) # updates the monitors in the ETS table
      {:reply, worker, %{state | workers: rest}}
    [] -> 
      {:reply, :noproc, state}
   end 
  end

  # number of workers available and number busy 
  def handle_call(:status, _from, %{workers: workers, monitors: monitors} = state) do
    {:reply, {length(workers), :ets.info(monitors, :size)}, state}
  end 

  # given a worker pid(worker) the entry is searched for in monitors ETS table -- 
  # if found - de-monitor and remove from table -- workers field of Server is updated with the additoin of the worker pid
  # if not found - do nothing 
  def handle_cast({:checkin, worker}, %{workers: workers, monitors: monitors} = state) do
    case :ets.lookup(monitors, worker) do
      [{pid, ref}] -> 
        true = Process.demonitor(ref)
        true = :ets.delete(monitors, pid)
        {:noreply, %{state | workers: [pid|workers]}}
      [] -> 
        {:noreply, state}
    end
  end

  #########
  #Private#
  #########
  # Process to be specified is a SUP not a worker
  defp supervisor_spec(mfa) do
    opts = [restart: :temporary] # turn off default restart -- want to add custom recovery rules in elsewhere
    supervisor(Pooly.WorkerSupervisor, [mfa], opts)
  end

  # prepopulate/2 takes a size and worker_Sup_pid and builds a list of size number workers
  defp prepopulate(size, sup) do
    prepopulate(size, sup, [])
  end
  defp prepopulate(size, _sup, workers) when size < 1 do
    workers
  end
  defp prepopulate(size, sup, workers) do
    prepopulate(size-1, sup, [new_worker(sup)|workers]) # Creates a list of workers attatched to the worker SUP
  end

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
  defp new_worker(sup) do
    {:ok, worker} = Supervisor.start_child(sup, [[]]) #dynamically creates a worker and attatches it to the SUP
    worker
  end

end # End Module

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

