defmodule Backend.Repo.Migrations.CreateReviews do
  use Ecto.Migration

  def change do
    create table(:reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :reviewer_id, :binary_id
      add :reviewee_id, :binary_id
      add :listing_id, :binary_id
      add :rating, :integer
      add :body, :string
      timestamps()
    end

    create index(:reviews, [:reviewee_id])
    create index(:reviews, [:listing_id])
  end
end
