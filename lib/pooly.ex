defmodule Pooly do
  use Application

  # When Pooly is started -- start/2 -- calls start/1 for convenience
  def start(_type, _args) do
    pools_config = [
      [name: "Pool1", mfa: {SampleWorker, :start_link, []}, size: 2],
      [name: "Pool2", mfa: {SampleWorker, :start_link, []}, size: 3],
      [name: "Pool3", mfa: {SampleWorker, :start_link, []}, size: 4],
    ]
    start_pools(pools_config)
  end

  def start_pools(pools_config) do
    Pooly.Supervisor.start_link(pools_config)
  end

  def checkout(pool_name) do
    Pooly.Server.checkout(pool_name)
  end

  def checkin(pool_name, worker_pid) do
    Pooly.Server.checkin(pool_name, worker_pid)
  end

  def status(pool_name) do
    Pooly.Server.status(pool_name)
  end
end
