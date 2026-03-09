# A2UI — AI-to-UI

A Flutter application that demonstrates the **A2UI (AI-to-UI)** paradigm: an LLM generates structured component trees at runtime, and the app renders them as fully native, interactive Flutter widgets. Instead of the AI responding with plain text, every response is a live UI surface the user can tap, slide, select, and submit.

## The Concept

Traditional chat-based AI apps display text responses. A2UI flips this — the AI **thinks in UI**. When the model responds, it emits a JSON component tree describing layout, widgets, data bindings, and user actions. The client interprets that tree and renders real Flutter widgets (sliders, choice chips, date pickers, emoji ratings, etc.) with two-way data binding. User interactions flow back to the model as structured context, enabling a multi-turn conversation conducted entirely through native UI — no chat bubbles required.

### How a Conversation Works

1. The user selects a topic agent (e.g. Mental Health, Travel Itinerary).
2. A system instruction tells the model which UI components are available, how to structure the JSON, and what the conversation flow should look like.
3. The model emits a `surfaceUpdate` containing a component tree (Column → ProgressIndicator + Text + MultipleChoice + Button).
4. The `genui` framework parses the JSON, resolves data paths, and renders native Flutter widgets.
5. When the user interacts (e.g. selects an option and taps "Continue"), a `UserActionEvent` carrying the resolved data is sent back to the model.
6. The model reads all previous answers from conversation history, asks the next question (a new surface), and after all questions are answered, generates a rich, personalized report — also rendered as native UI with images, cards, and styled text.

## Built-in Agents

| Agent | Description |
|---|---|
| Mental Health | Wellness check-in that produces a personalized action plan with a wellness score |
| Travel Itinerary | Trip planner that builds a day-by-day itinerary with budget breakdown |
| Fitness & Nutrition | Custom workout and nutrition plan with a 4-week milestone roadmap |
| Career Development | Strategic career plan with a 30-60-90 day action plan |

You can also create **custom agents** at runtime by providing a name, icon, and system prompt.

## Component Catalog

The app defines a custom widget catalog (`custom_catalog.dart`) that overrides the default `genui` core components with themed versions. Available components:

- **Layout** — `Column`, `Row`, `Card`, `ImageCard`
- **Input** — `MultipleChoice`, `Slider`, `RangeSlider`, `CheckBox`, `TextField`, `EmojiRating`, `DateTimeInput`
- **Display** — `Text` (with usage hints for visual hierarchy), `Image`, `ProgressIndicator`
- **Action** — `Button` (with `context` array for data resolution)

Each component supports **data binding** via JSON paths, so user selections are stored in a reactive data context and can be passed back to the model.

## Getting Started

### Prerequisites

- Flutter SDK `^3.11.0`
- A [Gemini API key](https://aistudio.google.com/apikey)

### Setup

1. **Clone the repository**

```bash
git clone <repo-url>
cd gen_ui
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Add your API key**

Create a `.env` file in the project root (or edit the existing one):

```
GEMINI_API_KEY=your_gemini_api_key_here
```

4. **Run the app**

```bash
flutter run
```

The app uses `flutter_dotenv` to load the key at startup and passes it to `GoogleGenerativeAiContentGenerator` with the `gemini-3-flash-preview` model.

## Project Structure

```
lib/
├── main.dart               # App entry point, agent selection page, chat page
├── system_instruction.dart  # System prompts for each agent (common core + per-topic)
├── custom_catalog.dart      # Themed widget catalog overriding genui core components
├── theme.dart               # App color palette and ThemeData
└── widget_preview_page.dart # Debug page to preview all catalog widgets
```

## Architecture

```
┌─────────────┐       system instruction        ┌──────────────────────┐
│  Agent       │──────────────────────────────▶  │  Gemini model        │
│  Config      │                                 │  (gemini-3-flash)    │
└─────────────┘                                  └──────────┬───────────┘
                                                            │
                                                   JSON component tree
                                                            │
                                                            ▼
┌─────────────┐    UserActionEvent + context      ┌──────────────────────┐
│  Flutter UI  │◀────────────────────────────────│  genui framework     │
│  (native     │────────────────────────────────▶│  (parse, bind,       │
│   widgets)   │                                 │   render, dispatch)  │
└─────────────┘                                  └──────────────────────┘
```

**Key packages:**

| Package | Role |
|---|---|
| `genui` | Core A2UI framework — catalog, surface rendering, data context, event dispatch |
| `genui_google_generative_ai` | Gemini adapter implementing `ContentGenerator` for the genui conversation loop |
| `json_schema_builder` | Defines JSON schemas for custom catalog items (ProgressIndicator, EmojiRating, RangeSlider) |
| `flutter_dotenv` | Loads the API key from `.env` |

## How the System Instruction Works

Each agent has a system instruction composed of three layers:

1. **Common Core** — rules every agent follows: one question per turn, how to call `surfaceUpdate`/`beginRendering`/`provideFinalOutput`, available components, data binding patterns, and how to remember answers across turns.
2. **Topic-Specific Role & Questions** — defines the agent's persona, conversation goal, and which wellness/travel/fitness/career dimensions to explore.
3. **Report Template** — structure the final report must follow (hero image, personalized analysis, actionable plan, section images from picsum.photos).

This layered approach means adding a new agent only requires writing the topic-specific section; the common instruction and report template are reused.

## Widget Preview

The app includes a **Widget Preview** page (accessible from the home screen) that renders every catalog item with its example data. This is useful for visually verifying component styling without running a full AI conversation.

## License

This project is provided as-is for demonstration purposes.
