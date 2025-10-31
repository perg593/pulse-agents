class CreateAIOutlineJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_outline_jobs do |t|
      t.references :survey, null: false, foreign_key: true
      t.references :prompt_template, null: true, foreign_key: true
      t.text :prompt_text
      t.boolean :use_default_prompt, default: false, null: false
      t.integer :status, null: false, default: 0
      t.text :outline_content
      t.text :error_message
      t.jsonb :filters, default: {}
      t.datetime :started_at
      t.datetime :completed_at      
      t.string :gamma_generation_id
      t.text :gamma_url
      t.datetime :gamma_started_at
      t.datetime :gamma_completed_at

      t.timestamps
    end

    add_index :ai_outline_jobs, :status
    add_index :ai_outline_jobs, [:survey_id, :created_at]
    add_index :ai_outline_jobs, :gamma_generation_id
  end
end
