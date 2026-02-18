class CreateEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :entities do |t|
      t.references :user, null: false, foreign_key: true,  index: { unique: true }

      t.timestamps
    end

    User.find_each do |user|
      Entity.create(user: user)
    end
  end
end
