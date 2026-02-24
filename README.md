# 🧠 NeuroVision — Assistive Learning Platform

> An accessible mobile learning platform designed for users with **ADHD, Dyslexia**, and **Visual Impairments**. Built with Flutter.

---

## 📋 Project Overview

NeuroVision is a single Flutter application containing **two independent assistive modules**:

| Module | Target Users | Key Features |
|--------|-------------|--------------|
| **Learning Mode** | ADHD & Dyslexia | Micro-learning blocks, focus tracking, pacing adjustment, gamified feedback |
| **Vision Mode** | Visually Impaired | Shape detection via ML Kit, vibration patterns, text-to-speech |

---

## 🏗️ Architecture

```
lib/
├── main.dart                          # App entry point
├── platform_core/                     # Central platform logic
│   ├── app.dart                       # Root widget with Provider & theme
│   ├── dashboard_screen.dart          # Main dashboard with mode selection
│   ├── router.dart                    # Module navigation router
│   ├── session_controller.dart        # State management (ChangeNotifier)
│   └── module_resolver.dart           # Module resolution utility
├── modules/
│   ├── learning/                      # MODULE 1: ADHD & Dyslexia
│   │   ├── learning_screen.dart       # Micro-learning UI
│   │   └── learning_logic.dart        # Content chunking & engagement
│   └── vision/                        # MODULE 2: Vision (Blind Support)
│       ├── vision_screen.dart         # Shape detection UI
│       └── vision_logic.dart          # Vibration + TTS logic
└── shared/
    ├── accessibility/
    │   ├── accessibility_theme.dart    # Shared high-contrast theme
    │   └── accessibility_prefs.dart   # User preference model
    ├── models/
    │   ├── user_profile.dart          # User profile model
    │   └── progress_model.dart        # Progress tracking model
    └── supabase/
        ├── supabase_client.dart       # Supabase connection (placeholder)
        └── supabase_service.dart      # Data operations (placeholder)
```

---

## 🎯 Features

### Dashboard
- Clean, high-contrast landing screen
- Two large, accessible mode-selection buttons
- Quick stats (blocks completed, focus streak, badges)
- Accessibility controls (font size slider, vibration toggle)

### Learning Mode (ADHD & Dyslexia)
- ✅ Micro-learning blocks — one short content block at a time
- ✅ Progress bar showing completion percentage
- ✅ Focus streak counter (gamified feedback)
- ✅ Rule-based time-on-task tracker
- ✅ Pacing adjustment prompts ("Would you like simpler content?")
- ✅ Dyslexia-friendly typography (Lexend font, generous spacing)
- ✅ Completion dialog with badge awards
- ✅ Minimal animations to reduce cognitive overload

### Vision Mode (Blind Support)
- ✅ Camera integration for shape detection (ML Kit, physical device)
- ✅ Demo mode with shape buttons for testing on emulator
- ✅ Vibration pattern encoding:
  - Circle → 2 short pulses
  - Square → 1 long steady vibration
  - Triangle → 3 rapid bursts
- ✅ Text-to-Speech announcing detected shapes
- ✅ 80% confidence threshold before feedback triggers
- ✅ Detection history log
- ✅ Audio/Vibration toggle controls

### Accessibility
- ✅ High-contrast dark theme (WCAG compliant)
- ✅ Dyslexia-friendly font (Lexend via Google Fonts)
- ✅ Adjustable font scale (80%–200%)
- ✅ Large touch targets (minimum 56dp)
- ✅ Semantic labels for screen readers
- ✅ Portrait-locked orientation

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| State Management | Provider (ChangeNotifier) |
| Vision AI | Google ML Kit (Object Detection) |
| Haptics | vibration package |
| Audio | flutter_tts (Text-to-Speech) |
| Typography | Google Fonts (Lexend) |
| Backend | Supabase (planned) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.8
- Android Studio or VS Code with Flutter extension
- Physical Android device (for Vision Mode camera features)

### Installation

```bash
# Clone the repository
git clone https://github.com/YOUR_ORG/neurovision-platform.git
cd neurovision-platform

# Install dependencies
flutter pub get

# Run on device/emulator
flutter run
```

---

## 👥 Team

| Role | Member | Folder Ownership |
|------|--------|-----------------|
| AI & NLP Lead | Member A | `lib/modules/learning/` |
| Vision & Haptics Lead | Member B | `lib/modules/vision/` |
| Frontend & UX Lead | Member C | `lib/platform_core/`, `lib/shared/` |
| Backend & Integration | Member D | `lib/shared/supabase/`, config |

---

## 📐 Design Principles

1. **Accessibility First** — Every design decision prioritizes usability for neurodiverse and visually impaired users
2. **Modular Architecture** — No overlapping functionality between modules
3. **Low Cognitive Load** — Minimal animations, high contrast, large targets
4. **Gamification** — Focus streaks and badges to maintain engagement
5. **Progressive Enhancement** — Demo modes for features requiring hardware

---

## 📄 License

MIT License — See [LICENSE](LICENSE) for details.
