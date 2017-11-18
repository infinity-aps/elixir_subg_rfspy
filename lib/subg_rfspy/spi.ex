defmodule SubgRfspy.SPI do
  @moduledoc """
  This GenServer provides the most basic read and write operations to communicate with a wireless chip running
  subg_rfspy firmware (https://github.com/ps2/subg_rfspy) over SPI.
  """

  defstruct name: nil, device: nil, reset_pin: nil

  require Logger
  use GenServer
  alias ElixirALE.{GPIO, SPI}

  @initial_byte 0x99

  def start_link(%SubgRfspy.SPI{name: name, device: device, reset_pin: reset_pin}) do
    GenServer.start_link(__MODULE__, [device, reset_pin], name: name)
  end

  @status_tx1 <<@initial_byte::8, 0x010100::24>>
  @status_tx2 <<@initial_byte::8, 0x00000000::32>>
  def init([device, reset_pin]) do
    with {:ok, serial_pid} <- SPI.start_link(device, [speed_hz: 62500]),
         {:ok, reset_pid} <- GPIO.start_link(reset_pin, :output),
         :ok <- _reset(reset_pid),
         transfer(serial_pid, @status_tx1),
         <<_::16>> <> "OK" <> <<_::8>> <- transfer(serial_pid, @status_tx2) do
      {:ok, %{serial_pid: serial_pid, reset_pid: reset_pid, read_queue: []}}
    else
      error ->
        Logger.error fn -> "The SPI failed to start: #{inspect(error)}" end
        {:error, "The SPI failed to start"}
    end
  end

  def chip_present?(%SubgRfspy.SPI{device: device, reset_pin: reset_pin}) do
    with {:ok, serial_pid} <- SPI.start_link(device, [speed_hz: 62500]),
         {:ok, reset_pid} <- GPIO.start_link(reset_pin, :output),
         :ok <- _reset(reset_pid),
         transfer(serial_pid, @status_tx1),
         <<_::16>> <> "OK" <> <<_::8>> <- transfer(serial_pid, @status_tx2) do

      SPI.release(serial_pid)
      GPIO.release(reset_pid)
      true
    else
      _error -> false
    end
  end

  def handle_call({:clear_buffers}, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call({:read, _timeout_ms}, _from, state = %{read_queue: [head | rest]}) do
    {:reply, {:ok, head}, Map.put(state, :read_queue, rest)}
  end

  def handle_call({:read, timeout_ms}, _from, state = %{serial_pid: serial_pid}) do
    timeout_time = System.monotonic_time(:millisecond) + timeout_ms + 5_000
    {:reply, _read(serial_pid, timeout_time), state}
  end

  def handle_call({:write, data, _timeout_ms}, _from, state = %{serial_pid: serial_pid}) do
    length_of_tx = byte_size(data)
    <<_::8, length_of_rx::8>> = transfer(serial_pid, <<@initial_byte::8, length_of_tx::8>>)
    extra_bits = (max(length_of_tx, length_of_rx) - length_of_tx) * 8
    tx_bytes = case extra_bits do
                 0 -> data
                 x -> data <> <<0x00::size(x)>>
               end
    rx = transfer(serial_pid, tx_bytes)
    state = case length_of_rx do
      0 -> state
      n ->
        bytes_to_read = n - 1
        <<real_rx::binary-size(bytes_to_read), _::binary>> = rx
        Map.put(state, :read_queue, state.read_queue ++ String.split(real_rx, <<0x00>>))
    end
    {:reply, :ok, state}
  end

  def handle_call({:reset}, _from, state = %{reset_pid: reset_pid}) do
    {:reply, _reset(reset_pid), state}
  end

  defp _reset(reset_pid) do
    GPIO.write(reset_pid, 0)
    :timer.sleep(10)
    GPIO.write(reset_pid, 1)
    :timer.sleep(2001)
    :ok
  end

  def terminate(reason, %{serial_pid: serial_pid}) do
    Logger.warn fn -> "Exiting, reason: #{inspect reason}" end
    SPI.release(serial_pid)
  end

  defp _read(pid, timeout_time) do
    case System.monotonic_time(:millisecond) do
      x when x > timeout_time -> {:error, :timeout}
      _ ->
        <<_::8, length_of_rx::8>> = transfer(pid, <<@initial_byte::8, 0x00::8>>)
        case length_of_rx do
          0 ->
            :timer.sleep(100)
            _read(pid, timeout_time)
          _ ->
            extra_bits = length_of_rx * 8
            tx_bytes = <<0x00::size(extra_bits)>>
            rx_byte_count = length_of_rx - 1
            <<rx::binary-size(rx_byte_count), _::8>> = transfer(pid, tx_bytes)
            {:ok, rx}
        end
    end
  end

  defp transfer(pid, data) do
    tx = data |> reverse_bits()
    rx = pid |> SPI.transfer(tx) |> reverse_bits()
    Logger.debug fn() -> "Sent: #{Base.encode16(data)} Received: #{Base.encode16(rx)}" end
    rx
  end

  defp reverse_bits(data), do: _reverse_bits(data, <<>>)
  defp _reverse_bits(<<>>, reversed), do: reversed
  defp _reverse_bits(<<first::binary-size(1), rest::binary>>, reversed) do
    <<a::1, b::1, c::1, d::1, e::1, f::1, g::1, h::1>> = first
    _reverse_bits(rest, <<reversed::binary, h::1, g::1, f::1, e::1, d::1, c::1, b::1, a::1>>)
  end
end
