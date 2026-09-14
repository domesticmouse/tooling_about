# tooling_about

A desktop Flutter client demonstrating Google **Antigravity** agent orchestration paired with **Generative UI** (`genui`) dynamic surfaces and real-time subprocess tracing.

---

## Features

- **Google Antigravity Agent Orchestration**: Connects to the local Antigravity runtime with support for Gemini models (`gemini-3.8-flash`, `gemini-2.5-pro`, `gemini-2.5-flash`).
- **Dynamic Generative UI (GenUI / A2UI)**: Renders interactive components generated in-stream by the agent, such as the custom `MultipleChoiceQuestion` card with automatic write-in options and user action dispatching.
- **Subprocess Trace Drawer**: Slide-out panel providing real-time visibility into all inbound (`<<<`), outbound (`>>>`), system, and error events with search filtering, directional filters, auto-scroll, and syntax-colored YAML formatting.
- **Collapsible Reasoning**: Live streaming and markdown formatting of model thought processes ("Thinking Process").
- **Fluid Desktop UX**:
  - Damped, physics-based scroll tracking with user-scroll detection and a resume FAB.
  - Multiline message composition with `Shift + Enter` (and `Enter` to submit).
  - Contextual error banners with a one-click `"Settings"` Call-to-Action.
- **Flexible Configuration**: Automatically uses `GEMINI_API_KEY` from the environment with support for in-app overrides and persistence via `SharedPreferences`.

---

## Architecture Overview

```
lib/
├── main.dart                       # App entrypoint and MaterialApp theme setup
├── models/
│   ├── chat_message.dart           # Chat message domain model with A2UI block stripping
│   └── process_log_entry.dart      # Subprocess trace event model
├── services/
│   └── antigravity_service.dart    # Agent lifecycle, GenUI controller, and logging bridge
├── ui/
│   ├── chat_screen.dart            # Main chat interface, bubble rendering, and shortcuts
│   ├── process_log_panel.dart      # Real-time slide-out subprocess trace panel
│   ├── settings_dialog.dart        # Model, API key, and instruction configuration
│   └── genui/
│       └── multiple_choice_question_item.dart # Custom GenUI CatalogItem with "Other" write-in
└── utils/
    └── yaml_highlighter.dart       # JSON-to-YAML parser and syntax highlighter
```

---

## Getting Started

### Prerequisites

- Flutter SDK (3.x or higher)
- A Google Gemini API Key

### Setting up the API Key

You can provide your Gemini API key in either of two ways:

1. **Environment Variable** (recommended for local development):
   ```bash
   export GEMINI_API_KEY="your-gemini-api-key"
   ```
2. **In-App Settings Dialog**:
   Launch the app, click the **Settings** icon (`Icons.tune`) in the AppBar or click **Settings** on the startup error banner, enter your key, and click **Save & Apply**.

### Running the App

Run the desktop application on macOS (or your target platform):

```bash
flutter run -d macos
```

---

## Verification & Testing

As specified in the project guidelines (`GEMINI.md`), all code changes must pass the verification suite:

```bash
# 1. Run automated test suite
flutter test

# 2. Format all Dart code
dart format .

# 3. Static analysis
dart analyze
```

---

## License

Open source and available under the [Apache License 2.0](LICENSE).

## Disclaimer

This is not an official Google product.
