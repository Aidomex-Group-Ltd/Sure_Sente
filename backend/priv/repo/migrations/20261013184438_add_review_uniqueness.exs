defmodule Backend.Repo.Migrations.AddReviewUniqueness do
  use Ecto.Migration

  def change do
    # 08-TRUST: one review per reviewer/reviewee pair per listing.
    create unique_index(:reviews, [:reviewer_id, :reviewee_id, :listing_id],
             name: :reviews_reviewer_reviewee_listing_uniq
           )

    # Profile-level reviews (no listing): one per reviewer/reviewee pair.
    create unique_index(:reviews, [:reviewer_id, :reviewee_id],
             name: :reviews_reviewer_reviewee_uniq,
             where: "listing_id IS NULL"
           )
  end
end
