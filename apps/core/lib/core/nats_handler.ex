defmodule Core.NatsHandler do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    {:ok, gnat} = Gnat.start_link(%{host: "127.0.0.1", port: 4222 })

    Gnat.sub(gnat, self(), "tx.*")

    {:ok, %{conn: gnat}}
  end

  def handle_info({:msg, data}, state) do
    IO.inspect(data)
    {:noreply, state}
  end
end
