defmodule EventStore.Storage do
  @moduledoc """
  Storage of events to a PostgreSQL database

  Uses a pool of connections to the database.
  This is for increased concurrency and performance, but with an upper limit on concurrent access.
  """

  require Logger

  alias EventStore.Snapshots.SnapshotData
  alias EventStore.Storage
  alias EventStore.Storage.{Reader,Snapshot,Stream,Subscription}

  @storage_pool_name :event_store_storage_pool

  @doc """
  Initialise the PostgreSQL database by creating the tables and indexes
  """
  def initialize_store! do
    execute_using_storage_pool(&Storage.Initializer.run!/1)
    :ok
  end

  @doc """
  Reset the PostgreSQL database by deleting all rows
  """
  def reset! do
    execute_using_storage_pool(&Storage.Initializer.reset!/1)
  end

  @doc """
  Create a new event stream with the given unique identifier
  """
  def create_stream(stream_uuid) do
    execute_using_storage_pool(&Stream.create_stream(&1, stream_uuid))
  end

  @doc """
  Read events for the given stream forward from the starting version, use zero for all events for the stream
  """
  def read_stream_forward(stream_id, start_version, count) do
    execute_using_storage_pool(&Reader.read_forward(&1, stream_id, start_version, count))
  end

  @doc """
  Read events for all streams forward from the starting event id, use zero for all events for all streams
  """
  def read_all_streams_forward(start_event_id, count) do
    execute_using_storage_pool(&Stream.read_all_streams_forward(&1, start_event_id, count))
  end

  @doc """
  Get the id of the last event persisted to storage
  """
  def latest_event_id do
    execute_using_storage_pool(&Stream.latest_event_id/1)
  end

  @doc """
  Get the id and version of the stream with the given uuid
  """
  def stream_info(stream_uuid) do
    execute_using_storage_pool(&Stream.stream_info(&1, stream_uuid))
  end

  @doc """
  Get the latest version of events persisted to the given stream
  """
  def latest_stream_version(stream_uuid) do
    execute_using_storage_pool(&Stream.latest_stream_version(&1, stream_uuid))
  end

  @doc """
  Create, or locate an existing, persistent subscription to a stream using a unique name and starting position (event id or stream version)
  """
  def subscribe_to_stream(stream_uuid, subscription_name, start_from_event_id \\ nil, start_from_stream_version \\ nil) do
    execute_using_storage_pool(&Subscription.subscribe_to_stream(&1, stream_uuid, subscription_name, start_from_event_id, start_from_stream_version))
  end

  @doc """
  Acknowledge receipt of an event by id, for a single subscription
  """
  def ack_last_seen_event(stream_uuid, subscription_name, last_seen_event_id, last_seen_stream_version) do
    execute_using_storage_pool(&Subscription.ack_last_seen_event(&1, stream_uuid, subscription_name, last_seen_event_id, last_seen_stream_version))
  end

  @doc """
  Unsubscribe from an existing named subscription to a stream
  """
  def unsubscribe_from_stream(stream_uuid, subscription_name) do
    execute_using_storage_pool(&Subscription.unsubscribe_from_stream(&1, stream_uuid, subscription_name))
  end

  @doc """
  Get all known subscriptions, to any stream
  """
  def subscriptions do
    execute_using_storage_pool(&Subscription.subscriptions/1)
  end

  @doc """
  Read a snapshot, if available, for a given source
  """
  def read_snapshot(source_uuid) do
    execute_using_storage_pool(&Snapshot.read_snapshot(&1, source_uuid))
  end

  @doc """
  Record a snapshot of the data and metadata for a given source
  """
  def record_snapshot(%SnapshotData{} = snapshot) do
    execute_using_storage_pool(&Snapshot.record_snapshot(&1, snapshot))
  end

  @doc """
  Delete an existing snapshot for a given source
  """
  def delete_snapshot(source_uuid) do
    execute_using_storage_pool(&Snapshot.delete_snapshot(&1, source_uuid))
  end

  # Execute the given `transaction` function using a database worker from the pool
  defp execute_using_storage_pool(transaction) do
    :poolboy.transaction(@storage_pool_name, transaction)
  end
end
