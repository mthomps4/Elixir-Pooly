# Pooly

Example of OTP Supervisor/Worker Pools

### Setup 
mix.exs -> application -> extra apps -> mod: {Pooly, []} #starts


### Path 
`Pooly` -> use Application 
```
  def start(_type, _args) do
    pools_config =
      [
        [name: "Pool1",
         mfa: {SampleWorker, :start_link, []},
         size: 2,
         max_overflow: 1
        ],
        [name: "Pool2",
         mfa: {SampleWorker, :start_link, []},
         size: 3,
         max_overflow: 0
        ],
        [name: "Pool3",
         mfa: {SampleWorker, :start_link, []},
         size: 4,
         max_overflow: 0
        ],
      ]

    start_pools(pools_config)
  end

  def start_pools(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end
  ...
```

Starts `Pooly.Supervisor` with configs 

`Pooly.Supervisor` starts supervisor 
starts workers with config from start 
```
  def init(pools_config) do
    children = [
      supervisor(Pooly.PoolsSupervisor, []),
      worker(Pooly.Server, [pools_config])
    ]

    opts = [strategy: :one_for_all,
            max_restart: 1,
            max_time: 3600]

    supervise(children, opts)
  end
```

`PoolsSupervisor` starts a one-for-one supervisor for the pools `PoolSupervisor1`

`Pooly.Server` -- GenServer for ??? 


