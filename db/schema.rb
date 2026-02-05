# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_12_09_142702) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "entities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_entities_on_user_id", unique: true
  end

  create_table "inventory_item_mutations", force: :cascade do |t|
    t.boolean "applied", default: false
    t.datetime "created_at", null: false
    t.integer "delta"
    t.bigint "inventory_slot_id", null: false
    t.string "item_type"
    t.datetime "updated_at", null: false
    t.index ["inventory_slot_id"], name: "index_inventory_item_mutations_on_inventory_slot_id"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.integer "count"
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_inventory_items_on_entity_id"
  end

  create_table "inventory_slots", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.bigint "inventory_item_id"
    t.integer "slot"
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_inventory_slots_on_entity_id"
    t.index ["inventory_item_id"], name: "index_inventory_slots_on_inventory_item_id", unique: true
    t.index ["slot", "entity_id"], name: "unique_inventory_slot_on_slot_and_entity_id", unique: true
  end

  create_table "loot_box_loots", force: :cascade do |t|
    t.boolean "claimed"
    t.integer "count"
    t.datetime "created_at", null: false
    t.integer "inventory_item_id", null: false
    t.integer "loot_box_id", null: false
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["inventory_item_id"], name: "index_loot_box_loots_on_inventory_item_id"
    t.index ["loot_box_id"], name: "index_loot_box_loots_on_loot_box_id"
  end

  create_table "loot_boxes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "opened_at"
    t.string "type"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_loot_boxes_on_user_id"
  end

  create_table "player_action_states", force: :cascade do |t|
    t.jsonb "action_state", null: false
    t.datetime "created_at", null: false
    t.string "player_action_name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["player_action_name", "user_id"], name: "unique_player_action_name_and_user_id", unique: true
    t.index ["user_id"], name: "index_player_action_states_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "entities", "users"
  add_foreign_key "inventory_item_mutations", "inventory_slots"
  add_foreign_key "inventory_items", "entities"
  add_foreign_key "inventory_slots", "entities"
  add_foreign_key "inventory_slots", "inventory_items"
  add_foreign_key "loot_box_loots", "inventory_items"
  add_foreign_key "loot_box_loots", "loot_boxes"
  add_foreign_key "loot_boxes", "users"
  add_foreign_key "player_action_states", "users"
  add_foreign_key "sessions", "users"
end
