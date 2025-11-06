Here’s how to wire up keyboard shortcuts and the Prompt Library in Cursor so the workflow you just designed becomes push-button simple.

	•	shift+cmd+ctrl+alt+a → opens a new Ask note preloaded with your Ask template.
	•	shift+cmd+ctrl+alt+p → opens a new Plan note using the Plan template.
	•	shift+cmd+ctrl+alt+d → jumps directly to your “Don’t-Do-This” log.
	•	shift+cmd+ctrl+alt+w → triggers your weekly summary Ask prompt.
	•	shift+cmd+ctrl+alt+t → quick blank template note.
	•	shift+cmd+ctrl+alt+l → quick open Ask/Plan docs.

⸻

⚙️ 1. Keyboard Shortcuts

Open Settings → Keyboard Shortcuts → + Add Shortcut and create these:

Shortcut
Name
Action

Cmd+Alt+A
New Ask note
Command: Ask → Save output using docs/templates/ask_template.md in docs/ask

Cmd+Alt+P
New Plan note
Command: Plan → Save output using docs/templates/plan_template.md in docs/planning

Cmd+Alt+D
Open Don’t-Do-This
Command: docs/decisions/dont-do-this.md

Cmd+Alt+W
Weekly Summary
Command: Ask: Summarize all /docs/ask and /docs/planning entries from the last 7 days into docs/weekly/YYYY-MM-DD_summary.md

You can also add:
	•	Cmd+Alt+T → Create template copy (duplicate whichever Ask/Plan template is open)
	•	Cmd+Alt+L → List recent Ask/Plan docs (use the "Open File" action with filter docs/ask OR docs/planning)

That gives you one-keystroke access to each piece of your documentation loop.


📚 2. Prompt Library setup

Go to Settings → Prompt Library → + Add Prompt and add these reusable prompts.

Prompt: Ask – Repo Map

Name: Repo Map
Shortcut: ask-repo-map

Prompt text:
Scan the repository. Summarize languages, build tools, top-level folders, and the ten largest or most-referenced files. Save results using docs/templates/ask_template.md.

Prompt: Ask – Call Flow
Identify all execution entry points (CLI, web, workers). For each, outline request→response flow and key modules. Save output using docs/templates/ask_template.md.

Prompt: Plan – Small Feature
Create a 4-step plan for implementing <feature>. 
Each step should include: 
- files to touch 
- tests to run 
- rollback strategy 
Add approval gates after risky steps. 
Use docs/templates/plan_template.md.

Prompt: Plan – Refactor
Generate a plan for safely refactoring <module>. 
List steps, risks, and test coverage. 
Do not change code yet. 
Save to docs/planning/<date>_refactor_<module>.plan.md.

Prompt: Ask – Weekly Summary
Summarize all Ask and Plan notes in docs/ask and docs/planning from the last 7 days. Identify themes, blockers, and next actions. Save to docs/weekly/YYYY-MM-DD_summary.md.



🧠 3. Pin your documentation context

In Cursor’s sidebar:
	•	Pin docs/templates/ and docs/decisions/dont-do-this.md.
	•	Keep them open so Ask and Plan see them as context—Cursor’s LLM will automatically follow your conventions when saving.



🔄 4. Testing the setup
	1.	Hit Cmd+Alt+A → run an Ask prompt.
	•	It should open a new Markdown file inside /docs/ask/ with your template pre-filled.
	2.	Hit Cmd+Alt+P → create a Plan note.
	3.	Type Cmd+Alt+D → jumps to your “Don’t-Do-This” log.
	4.	Once a week: Cmd+Alt+W → run the Weekly Summary prompt.