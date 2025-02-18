defmodule Core.Schema.ChainSyncStatus do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}
  @type sync_range :: %{start_block: integer(), end_block: integer()}

  @primary_key {:chain_name, :string, []}
  schema "chain_sync_status" do
    field :latest_block_number, :integer
    field :latest_block_hash, :string
    field :earliest_block_number, :integer
    field :earliest_block_hash, :string
    field :safe_block_number, :integer
    field :sync_status, :string
    field :error_message, :string
    field :syncing_ranges, {:array, :map}, default: []

    timestamps(type: :utc_datetime)
  end

  @required_fields [
    :chain_name,
    :latest_block_number,
    :latest_block_hash,
    :earliest_block_number,
    :safe_block_number,
    :sync_status
  ]
  @optional_fields [:error_message, :earliest_block_hash, :syncing_ranges]

  @doc false
  def changeset(status, attrs) do
    status
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:sync_status, ["syncing", "synced", "error"])
    |> validate_block_numbers()
    |> validate_syncing_ranges()
  end

  defp validate_block_numbers(changeset) do
    case {
      get_field(changeset, :earliest_block_number),
      get_field(changeset, :safe_block_number),
      get_field(changeset, :latest_block_number)
    } do
      {earliest, safe, latest}
      when is_integer(earliest) and is_integer(safe) and is_integer(latest) and
             earliest <= safe and safe <= latest ->
        changeset

      _ ->
        add_error(
          changeset,
          :block_numbers,
          "earliest_block_number <= safe_block_number <= latest_block_number must be satisfied"
        )
    end
  end

  defp validate_syncing_ranges(changeset) do
    case get_field(changeset, :syncing_ranges) do
      nil ->
        changeset

      ranges when is_list(ranges) ->
        if Enum.all?(ranges, &valid_sync_range?/1) do
          changeset
        else
          add_error(changeset, :syncing_ranges, "contains invalid range format")
        end

      _ ->
        add_error(changeset, :syncing_ranges, "must be a list of ranges")
    end
  end

  defp valid_sync_range?(%{start_block: start, end_block: end_block})
       when is_integer(start) and is_integer(end_block) and start <= end_block,
       do: true

  defp valid_sync_range?(_), do: false
end
