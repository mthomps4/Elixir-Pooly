defmodule SampleWorker do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def stop(pid) do
    GenServer.call(pid, :stop)
  end

  def work_for(pid, duration) do
    GenServer.cast(pid, {:work_for, duration})
  end

  def handle_call(:stop, _from, state) do
    {:stop, :normal, :ok, state}
  end

  def handle_cast({:work_for, duration}, state) do
    :timer.sleep(duration)
    {:stop, :normal, state}
  end

end


# {:ok, worker_sup} = Pooly.WorkerSupervisor.start_link({SampleWorker, :start_link, []})
# > :OK PID

# add a few children 
# Supervisor.start_child(worker_sup, [[]])

# Supervisor.which_children(worker_sup)
# > [{:undefined, #PID<0.115.0>, :worker, [SampleWorker]},
#  {:undefined, #PID<0.117.0>, :worker, [SampleWorker]},
#  {:undefined, #PID<0.119.0>, :worker, [SampleWorker]},
#  {:undefined, #PID<0.121.0>, :worker, [SampleWorker]},
#  {:undefined, #PID<0.123.0>, :worker, [SampleWorker]}]

# Supervisor.count_children(worker_sup)
# > %{active: 5, specs: 1, supervisors: 0, workers: 5}

# {:ok, worker_pid} = Supervisor.start_child(worker_sup, [[]])
# SampleWorker.stop(worker_pid)
 # > :OK

# Supervisor.which_children(worker_sup)