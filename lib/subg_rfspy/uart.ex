defmodule SubgRfspy.UART do
  @moduledoc """
  This GenServer provides the most basic read and write operations to communicate with a wireless chip running
  subg_rfspy firmware (https://github.com/ps2/subg_rfspy) over a UART.
  """

  defstruct name: nil, device: nil

  require Logger
  use GenServer
  alias SubgRfspy.UARTFraming
  alias Nerves.UART

  def start_link(%SubgRfspy.UART{name: name, device: device}) do
    GenServer.start_link(__MODULE__, device, name: name)
  end

  @reset 0x07
  def init(device) do
    with {:ok, serial_pid} <- UART.start_link,
         :ok <- UART.open(serial_pid, device, speed: 19_200, active: false),
         :ok <- UART.configure(serial_pid, framing: {UARTFraming, separator: <<0x00>>}),
         :ok <- UART.flush(serial_pid) do

      {:ok, serial_pid}
    else
      error ->
        Logger.error fn -> "The UART failed to start: #{inspect(error)}" end
        {:error, "The UART failed to start"}
    end
  end

  def chip_present?(%SubgRfspy.UART{device: device}) do
    with {:ok, serial_pid} <- UART.start_link,
         :ok <- UART.open(serial_pid, device, speed: 19_200, active: false),
         :ok <- UART.configure(serial_pid, framing: {UARTFraming, separator: <<0x00>>}),
         :ok <- UART.flush(serial_pid),
         :ok <- write_fully(<<@reset>>, 100, serial_pid),
         :timer.sleep(2000),
         :ok <- write_fully(<<0x01>>, 100, serial_pid),
         {:ok, "OK"} <- UART.read(serial_pid, 2_000) do

      UART.stop(serial_pid)
      true
    else
      _error -> false
    end
  end

  def terminate(reason, serial_pid) do
    Logger.warn fn -> "Exiting, reason: #{inspect reason}" end
    UART.close(serial_pid)
  end

  def handle_call({:write, data, timeout_ms}, _from, serial_pid) do
    {:reply, write_fully(data, timeout_ms, serial_pid), serial_pid}
  end

  def handle_call({:read, timeout_ms}, _from, serial_pid) do
    # is_uart_running = "ps" |> System.cmd([]) |> elem(0) |> String.contains?("uart")
    # if !is_uart_running do
    #   Logger.debug fn -> "UART port is not running!" end
    # end
    {:reply, UART.read(serial_pid, timeout_ms + 1_000), serial_pid}
  end

  def handle_call({:clear_buffers}, _from, serial_pid) do
    {:reply, UART.flush(serial_pid), serial_pid}
  end

  defp write_fully(data, timeout_ms, serial_pid) do
    case UART.write(serial_pid, data, timeout_ms) do
      :ok -> UART.drain(serial_pid)
      err -> err
    end
  end
end
