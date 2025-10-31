class CreatePromptTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :prompt_templates do |t|
      t.string :name, null: false
      t.text :content, null: false
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end

    add_index :prompt_templates, :is_default
    add_index :prompt_templates, :name, unique: true
  end
end
