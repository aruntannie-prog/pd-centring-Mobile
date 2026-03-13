# Superpowers Skills

This project uses the [obra/superpowers](https://github.com/obra/superpowers) skill system.

Skills are in `.agent/skills/`. Read and follow them before starting any task.

## Auto-load

@.agent/skills/using-superpowers/SKILL.md
@.agent/skills/using-superpowers/references/gemini-tools.md

## Available Skills

| Skill | When to Use |
|-------|-------------|
| `brainstorming` | Before starting ANY new feature or significant change |
| `writing-plans` | After spec is approved — to create the implementation plan |
| `executing-plans` | To execute an existing implementation plan |
| `requesting-code-review` | After completing a feature or before merging |
| `verification-before-completion` | Before claiming any work is done |
| `finishing-a-development-branch` | After implementation is complete |

## Project Context

**PD Centring** — Flutter mobile/web app for a centring materials rental business.

- **Backend:** Firebase Firestore
- **State:** Provider (`AppStore`)
- **Key files:** `lib/models/bill.dart`, `lib/models/store.dart`, `lib/screens/new_bill.dart`, `lib/screens/bill_detail.dart`
- **Branches:** `master` (main), push to `mobile` remote for mobile builds
- **Build:** `flutter run` (dev), `flutter build apk --release` (production)

## Workflow

```
brainstorming → writing-plans → executing-plans → requesting-code-review → finishing-a-development-branch
```

Always brainstorm before writing any code for new features.
