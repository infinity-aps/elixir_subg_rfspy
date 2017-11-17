defmodule SubgRfspy do
  @moduledoc """
  This module models the serial communications with a chip running the subg_rfspy firmware
  (https://github.com/ps2/subg_rfspy). The lower level serial communication is handled by a driver such as
  SubgRfspy.UART.
  """

  require Logger
  use Bitwise

  @serial_timeout_ms_padding 1000

  @channel 0
  @retry_count 0
  @repetitions 1
  @repetition_delay 0

  @commands %{
    get_state:       0x01,
    get_version:     0x02,
    get_packet:      0x03,
    send_packet:     0x04,
    send_and_listen: 0x05,
    update_register: 0x06,
    reset:           0x07
  }

  @registers %{
    freq2:    0x09,
    freq1:    0x0A,
    freq0:    0x0B,
    mdmcfg4:  0x0C,
    mdmcfg3:  0x0D,
    mdmcfg2:  0x0E,
    mdmcfg1:  0x0F,
    mdmcfg0:  0x10,
    agcctrl2: 0x17,
    agcctrl1: 0x18,
    agcctrl0: 0x19,
    frend1:   0x1A,
    frend0:   0x1B
  }

  def update_register(%{name: name}, register, value) do
    GenServer.call(name, {:clear_buffers})
    write_command(name, <<register::8, value::8>>, :update_register, 100)

    true = read_until(name, <<1>>, 5)
  end

  def set_base_frequency(chip, mhz) do
    freq_xtal = 24_000_000
    val = round((mhz * 1_000_000) / (freq_xtal / :math.pow(2, 16)))
    update_register(chip, @registers[:freq0], val &&& 0xff)
    update_register(chip, @registers[:freq1], (val >>> 8) &&& 0xff)
    update_register(chip, @registers[:freq2], (val >>> 16) &&& 0xff)
    {:ok}
  end

  def read(%{name: name}, timeout_ms \\ 1000) do
    write_command(name, <<@channel::8, timeout_ms::32>>, :get_packet, timeout_ms + 1000)
    name |> read_response(timeout_ms) |> process_response()
  end

  def write(%{name: name}, packet, repetitions, repetition_delay, timeout_ms) do
    write_batches(name, packet, repetitions, repetition_delay, timeout_ms)
  end

  def write_and_read(%{name: name}, packet, timeout_ms \\ 500) do
    command = <<@channel::8, @repetitions::8, @repetition_delay::8,
      @channel::8, timeout_ms::size(32), @retry_count::8,
      packet::binary>>
    write_command(name, command, :send_and_listen, timeout_ms + @serial_timeout_ms_padding)
    padded_timeout = timeout_ms + @serial_timeout_ms_padding
    name |> read_response(padded_timeout) |> process_response()
  end

  def reset(%{name: name}) do
    :ok = write_command(name, <<>>, :reset, 100)
  end

  def sync(name) do
    GenServer.call(name, {:clear_buffers})
    {:ok, status} = get_state(name)
    {:ok, version} = get_version(name)
    %{status: status, version: version}
  end

  def get_version(%{name: name}) do
    :ok = write_command(name, <<>>, :get_version, 100)
    read_response(name, 5000)
  end

  def get_state(%{name: name}) do
    :ok = write_command(name, <<>>, :get_state, 100)
    read_response(name, 5000)
  end

  @max_repetition_batch_size 250
  defp write_batches(name, packet, repetitions, repetition_delay, timeout_ms) do
    case repetitions do
      x when x > @max_repetition_batch_size ->
        write_batch(name, packet, repetitions - @max_repetition_batch_size, repetition_delay, timeout_ms)
        read_response(name, timeout_ms)

        write_batches(name, packet, repetitions - @max_repetition_batch_size, repetition_delay, timeout_ms)
      _ ->
        write_batch(name, packet, repetitions, repetition_delay, timeout_ms)
    end
  end

  defp write_batch(name, packet, repetitions, repetition_delay, timeout_ms) do
    command = <<@channel::8, repetitions::8, repetition_delay::8, packet::binary>>
    write_command(name, command, :send_packet, timeout_ms)

    read_response(name, timeout_ms)
  end

  defp write_command(name, param, command_type, timeout_ms) do
    command = @commands[command_type]
    real_timeout = timeout_ms + 10_000
    response = GenServer.call(name, {:write, <<command::8>> <> param, real_timeout}, genserver_timeout(real_timeout))
    if command_type == :reset do
      :timer.sleep(5000)
    end
    response
  end

  @timeout             0xAA
  @command_interrupted 0xBB
  @zero_data           0xCC
  defp read_response(name, timeout_ms) do
    response = GenServer.call(name, {:read, timeout_ms}, genserver_timeout(timeout_ms))
    case response do
      {:ok, <<@command_interrupted>>} ->
        Logger.debug fn -> "Command Interrupted, continuing to read" end
        read_response(name, timeout_ms)
      _ ->
        response
    end
  end

  defp process_response({:error, :timeout}),              do: {:error, :timeout}
  defp process_response({:ok, <<@timeout>>}),             do: {:error, :timeout}
  defp process_response({:ok, <<>>}),                     do: {:error, :empty}
  defp process_response({:ok, <<@command_interrupted>>}), do: {:error, :command_interrupted}
  defp process_response({:ok, <<@zero_data>>}),           do: {:error, :zero_data}
  defp process_response({:ok, <<raw_rssi::8, sequence::8, data::binary>>}) do
    {:ok, %{rssi: rssi(raw_rssi), sequence: sequence, data: data}}
  end

  @rssi_offset 73
  defp rssi(raw_rssi) when raw_rssi >= 128, do: rssi(raw_rssi - 256)
  defp rssi(raw_rssi), do: (raw_rssi / 2) - @rssi_offset

  defp read_until(name, _, 0), do: false
  defp read_until(name, expected, retries) do
    case read_response(name, 100) do
      {:ok, ^expected} -> true
      _                -> read_until(name, expected, retries - 1)
    end
  end

  defp genserver_timeout(timeout_ms), do: timeout_ms + 10_000
end
