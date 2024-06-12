defmodule Batches do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:merkle_root, :string, autogenerate: false}
  schema "batches" do
    field :amount_of_proofs, :integer
    field :is_verified, :boolean
    #new params:
    field :submition_block_number, :integer
    field :submition_transaction_hash, :string
    field :submition_timestamp, :utc_datetime
    field :response_block_number, :integer
    field :response_transaction_hash, :string
    field :response_timestamp, :utc_datetime
    field :data_pointer, :string

    timestamps()
  end

  @doc false
  def changeset(new_batch, updates) do
    new_batch
    |> cast(updates, [:merkle_root, :amount_of_proofs, :is_verified, :submition_block_number, :submition_transaction_hash, :submition_timestamp, :response_block_number, :response_transaction_hash, :response_timestamp, :data_pointer])
    |> validate_required([:merkle_root, :amount_of_proofs, :is_verified, :submition_block_number, :submition_transaction_hash, :submition_timestamp])
    |> validate_format(:merkle_root, ~r/0x[a-fA-F0-9]{64}/)
    |> unique_constraint(:merkle_root)
    |> validate_number(:amount_of_proofs, greater_than: 0)
    |> validate_inclusion(:is_verified, [true, false])
    |> validate_number(:submition_block_number, greater_than: 0)
    |> validate_format(:submition_transaction_hash, ~r/0x[a-fA-F0-9]{64}/)
    |> validate_number(:response_block_number, greater_than: 0)
    |> validate_format(:response_transaction_hash, ~r/0x[a-fA-F0-9]{64}/)
  end

  def cast_to_batches(%BatchDB{} = batch_db) do
    %Batches{
      merkle_root: batch_db.merkle_root,
      amount_of_proofs: batch_db.amount_of_proofs,
      is_verified: batch_db.is_verified,
      submition_block_number: batch_db.submition_block_number,
      submition_transaction_hash: batch_db.submition_transaction_hash,
      submition_timestamp: batch_db.submition_timestamp,
      response_block_number: batch_db.response_block_number,
      response_transaction_hash: batch_db.response_transaction_hash,
      response_timestamp: batch_db.response_timestamp,
      data_pointer: batch_db.data_pointer
    }
  end

  def generate_changeset(%BatchDB{} = batch_db) do
    Batches.changeset(%Batches{}, Map.from_struct(Batches.cast_to_batches(batch_db)))
  end

  def get_amount_of_submitted_proofs() do
    case Explorer.Repo.aggregate(Batches, :sum, :amount_of_proofs) do
      nil -> 0
      result -> result
    end
  end

  def get_amount_of_verified_proofs() do
    query = from(b in Batches,
      where: b.is_verified == true,
      select: sum(b.amount_of_proofs))

    case Explorer.Repo.one(query) do
      nil -> 0
      result -> result
    end
  end

  def get_amount_of_verified_batches() do
    query = from(b in Batches,
      where: b.is_verified == true,
      select: count(b.merkle_root))

    case Explorer.Repo.one(query) do
      nil -> 0
      result -> result
    end
  end

  def get_latest_batches(%{amount: amount}) do
    query = from(b in Batches,
      order_by: [desc: b.submition_block_number],
      limit: ^amount,
      select: b)

    Explorer.Repo.all(query)
  end

  def insert_or_update(changeset) do
    merkle_root = changeset.changes.merkle_root
    case Explorer.Repo.get(Batches, merkle_root) do
      nil ->
        "New Batch, inserting to DB:" |> IO.puts()
        Explorer.Repo.insert(changeset) #this is missing all the juicy info
      existing_batch ->
        if existing_batch.is_verified != changeset.changes.is_verified                                #changed status
          # or existing_batch.response_block_number != changeset.changes.response_block_number          #reorg
          # or existing_batch.response_transaction_hash != changeset.changes.response_transaction_hash  #reorg
        do
          "Batch values have changed, updating in DB" |> IO.puts()
          updated_changeset = Ecto.Changeset.change(existing_batch, changeset.changes)
          Explorer.Repo.update(updated_changeset)
        end
    end
  end

  def get_unverified_batches() do
    query = from(b in Batches,
      where: b.is_verified == false, # TODO add and b.response_block_number > 24 hs
      select: b)

    Explorer.Repo.all(query)
  end

  def get_batch(%{merkle_root: merkle_root}) do
    query = from(b in Batches,
      where: b.merkle_root == ^merkle_root,
      select: b)

    Explorer.Repo.one(query)
  end
end