defmodule NSQ.ConsumerTest do
  use ExUnit.Case
  # doctest NSQ.Consumer

  @test_topic "__nsq_consumer_test_topic__"
  @test_channel1 "__nsq_consumer_test_channel1__"
  @test_channel2 "__nsq_consumer_test_channel2__"

  def new_test_consumer(handler) do
    consumer = NSQ.Consumer.new(@test_topic, @test_channel1, %{
      nsqds: [{"127.0.0.1", 6750}],
      handler: handler
    })
  end

  setup do
    HTTPotion.start
    HTTPotion.post("http://127.0.0.1:6751/topic/delete?topic=#{@test_topic}")
    :ok
  end

  test "#new establishes a connection to NSQ" do
    test_pid = self
    consumer = new_test_consumer fn(body, msg) ->
      assert body == "HTTP message"
      assert msg.attempts == 1
      send(test_pid, :handled)
      {:ok}
    end

    HTTPotion.post("http://127.0.0.1:6751/put?topic=#{@test_topic}", [body: "HTTP message"])

    receive do
      :handled -> :ok
    after
      500 ->
        raise "timed out waiting for message to be processed"
        :timeout
    end
  end
end