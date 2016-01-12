defmodule NSQ.Connection.Command do
  @moduledoc """
  Both consumers and producers use Connection, which, at a lower level, kicks
  off message processing and issues commands to NSQD. This module handles some
  of the trickier command queueing, flushing, etc.
  """


  alias NSQ.Connection, as: C
  alias NSQ.ConnInfo
  import NSQ.Protocol


  @spec send_data_and_queue_resp(S.state, tuple, {reference, pid}, atom) :: C.state
  def send_data_and_queue_resp(state, cmd, from, kind) do
    state.socket |> Socket.Stream.send!(encode(cmd))
    if kind == :noresponse do
      state
    else
      %{state |
        cmd_resp_queue: :queue.in({cmd, from, kind}, state.cmd_resp_queue)
      }
    end
  end

  @spec flush_cmd_queue(C.state) :: C.state
  def flush_cmd_queue(state) do
    {item, new_queue} = :queue.out(state.cmd_queue)
    case item do
      {:value, {cmd, from, kind}} ->
        state = send_data_and_queue_resp(state, cmd, from, kind)
        flush_cmd_queue(%{state | cmd_queue: new_queue})
      :empty ->
        %{state | cmd_queue: new_queue}
    end
  end

  @spec update_state_from_cmd(tuple, C.state) :: C.state
  def update_state_from_cmd(cmd, state) do
    case cmd do
      {:rdy, count} ->
        ConnInfo.update(state, %{rdy_count: count, last_rdy: count})
        state
      _any -> state
    end
  end
end