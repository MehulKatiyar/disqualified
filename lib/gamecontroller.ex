defmodule Disqualified.GameController do
  use GenServer
  require Logger

  def start_link do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def init(_opts) do
    {:ok, client} = Mqtt.connect
    :ok = Mqtt.subscribe(client, "/+/init", 1)
    :ok = Mqtt.subscribe(client, "/+/register", 1)
    :ok = Mqtt.subscribe(client, "/+/results", 1)
    {:ok, %{client: client}}
  end

  def handle_info({:mqttc, _channel, :connected}, %{client: client}) do
    Logger.debug "Game Controller connected"
    {:noreply, %{client: client}}
  end

  def handle_info({:publish, channel, payload}, %{client: client}) do
    mqtt_receive(channel, payload, client)
    {:noreply, %{client: client}}
  end

  def handle_info(message, %{client: client}) do
    Logger.warn "Published Unmatched Event: #{inspect message}"
    {:noreply, %{client: client}}
  end

  def terminate(reason, _state) do
    Logger.warn "Terminated: #{inspect reason}"
    {:ok, reason}
  end

  def mqtt_receive(channel, payload, client) do
    [ _, game_id, values] = String.split(channel, "/")
    case values do
      "init" ->
        Logger.debug "Game started. Game Id: " <> game_id
        publish_random(client, game_id)
      _ ->
        Logger.debug "Unknown message"
    end
  end

  def publish_random(client, game_id) do
    :random.seed :erlang.now
    list = Stream.repeatedly(&:random.uniform/0)
    |> Enum.take(50)

    {:ok, numbers} =
      Enum.map(list, fn(x) -> convert_to_integer(x) end)
    |> JSON.encode
    Mqtt.publish(client, "/" <> game_id <> "/fetch", numbers, 1)
  end

  defp convert_to_integer(x) do
    Float.round(x*2)
  end
end
