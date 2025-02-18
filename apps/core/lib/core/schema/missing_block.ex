defmodule Core.Schema.MissingBlock do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
  alias Core.Repo

  schema "missing_blocks" do
    field :chain, :string
    field :block_number, :integer
    field :block_hash, :string
    field :error_type, :string
    field :error_message, :string
    field :attempts, :integer, default: 1
    field :last_attempt_at, :utc_datetime
    field :status, :string, default: "pending"
    field :priority, :integer, default: 0
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime)
  end

  @required_fields [:chain, :block_number, :error_type, :last_attempt_at]
  @optional_fields [
    :block_hash,
    :error_message,
    :attempts,
    :status,
    :priority,
    :metadata
  ]

  @valid_chains ["ethereum", "solana"]
  @valid_statuses ["pending", "retrying", "resolved", "failed"]

  @doc false
  def changeset(missing_block, attrs) do
    missing_block
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:chain, @valid_chains)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:attempts, greater_than_or_equal_to: 1)
    |> validate_number(:priority, greater_than_or_equal_to: 0, less_than_or_equal_to: 10)
    |> unique_constraint([:chain, :block_number])
  end

  @doc """
  Records a failed block attempt.
  """
  def record_failure(chain, block_number, error_type, opts \\ []) do
    attrs = %{
      chain: Atom.to_string(chain),
      block_number: block_number,
      error_type: error_type,
      block_hash: opts[:block_hash],
      error_message: opts[:error_message],
      last_attempt_at: DateTime.utc_now(),
      priority: opts[:priority] || 0,
      metadata: opts[:metadata] || %{}
    }

    case Repo.get_by(__MODULE__, chain: attrs.chain, block_number: block_number) do
      nil ->
        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> changeset(
          Map.merge(attrs, %{
            attempts: existing.attempts + 1,
            status: if(existing.attempts >= 5, do: "failed", else: "pending")
          })
        )
        |> Repo.update()
    end
  end

  @doc """
  Marks a missing block as resolved.
  """
  def mark_resolved(chain, block_number) do
    case Repo.get_by(__MODULE__, chain: Atom.to_string(chain), block_number: block_number) do
      nil ->
        {:error, :not_found}

      missing_block ->
        missing_block
        |> changeset(%{status: "resolved"})
        |> Repo.update()
    end
  end

  @doc """
  Gets pending missing blocks for a chain, ordered by priority and attempts.
  """
  @spec get_pending_blocks(atom(), pos_integer()) :: [%__MODULE__{}]
  def get_pending_blocks(chain, limit \\ 100)
      when is_atom(chain) and is_integer(limit) and limit > 0 do
    from(b in __MODULE__,
      where: b.chain == ^Atom.to_string(chain) and b.status in ["pending", "retrying"],
      order_by: [desc: b.priority, asc: b.attempts, asc: b.block_number],
      limit: ^limit
    )
    |> Repo.all()
  end
end
