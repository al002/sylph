defmodule Core.Schema.IndexerTask do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "indexer_tasks" do
    field :chain, :string
    field :task_type, :string
    field :status, :string
    field :data, :map
    field :attempts, :integer, default: 0
    field :error, :string

    timestamps(type: :utc_datetime)
  end

  @required_fields [:chain, :task_type, :status, :data]
  @optional_fields [:attempts, :error]
  @task_types ["block", "transaction", "token", "contract"]
  @statuses ["pending", "processing", "completed", "failed"]

  @doc false
  def changeset(task, attrs) do
    task
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:chain, ["ethereum", "solana"])
    |> validate_inclusion(:task_type, @task_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> validate_data()
  end

  defp validate_data(changeset) do
    case get_field(changeset, :data) do
      data when is_map(data) -> changeset
      _ -> add_error(changeset, :data, "must be a valid JSON object")
    end
  end
end
