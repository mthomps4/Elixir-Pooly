defmodule Pooly.WorkerSupervisor do
  use Supervisor

  #####
  #API#
  #####

  def start_link(pool_server, {_,_,_} = mfa) do
    Supervisor.start_link(__MODULE__, [pool_server, mfa])
  end
  ###########
  #CALLBACKS#
  ###########

  # Matches from start_link [server, {module, function, args}]
  def init([pool_server, {m,f,a}]) do
    Process.link(pool_server)
    worker_opts = [
      shutdown: 5000,
      function: f
    ]

    children = [worker(m, a, worker_opts)]
    opts     = [
      strategy:    :simple_one_for_one,
      max_restarts: 5,
      max_seconds:  5
    ]

    supervise(children, opts)
  end
end


# NOTES: 
# The child specification is created with Supervisor.Spec.worker/3
# imported by Supervisor behavior by default 
# there's no need to supply the fully qualified version. 

# The return of init/1 must be a supervisor specification. In order to construct a supervisor spec you use the Supervisor.Spec.supervise(children, opts)
# Takes a list of children and a kewyword list of options. 

### Restart Strategies 
# dictate how a Supervisor restarts a child/children when something is wrong 
# strategy key with 
# :one_for_one, :one_for_all, :rest_for_one, :simple_one_for_one
# :one_for_one -- if the process dies only that process is restarted. None of the others are affected. 
# :one_for_all -- if ANY process dies, all the processes in the supervision tree die with it. After ALL are restarted 
# :rest_for_one -- If one of the processes dies, the rest of the processes that were started AFTER that process are terminated. After that, the process that died and those after are restarted
# ^^ Used to build a static supervisor tree. workers are specified up front with child specs
# :simple_one_for_one -- you specify only ONE entry in the child specs. Every child process that's spawned from this Supervisor is the same kind of process. 
# ^ Like a factory method (or a constructor in OOP) where workers that are produced are alike. 
# simple_one_for_one is used when you want to dynamically create workers. 
# The Supervisor initlally starts out with empty workers. Workers are then dynamically attatched to the SUP. 

### max_restart and max_seconds 
# Number of restarts in number of seconds before the SUP gives up and terminates
# DEFAULT 3 restarts in 5 seconds 

### defining Children 
# children = [worker(m, a, worker_opts)]
# SUP has one child, or one kind of child :simple_one_for_one 
# In general you don't know how many workers you want to spawn when using :simple_one_for_one
# worker/3 creates a child spec for a worker, as opposed to its sibling supervisor/3
# if the child isn't a SUP use worker/3 if it is use supervisor/3 
# IF you leave out the child spec options children = [worker(m, a)]
# Elixir will add these by default --
  #[id: module, function: :start_link, restart: :permanent, shutdown: :infinity, modules: [module]]

  ## restart option 
  # permanent & temporary (always, never)

  
