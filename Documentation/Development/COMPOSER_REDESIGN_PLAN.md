# Composer Redesign Plan

## Objective
Redesign the composer in `ConversationScreenView` to be more compact, modern, and non-dominant, in the style of Gemini/ChatGPT.

## Requirements
- **Compact UI**: The composer should occupy less vertical space by default.
- **Dynamic Height**: 
    - 1 line default (minimal height).
    - Grow dynamically when typing up to 4–6 lines.
    - Scrollable if content exceeds the maximum height.
- **UX/Architecture**:
    - No changes to business logic or Frozen APIs.
    - Maintain existing streaming/disabled/error states.
    - Ensure accessibility and keyboard handling remain functional.
    - Test on iOS (Portrait/Landscape) and macOS.

## Implementation Steps
1. **Analyze `ConversationScreenView`**: Examine the existing `composer` view, `composerHeight` logic, and `TextEditor` binding.
2. **UI Modification**:
    - Use `TextEditor` (or `TextField` with `axis: .vertical`) to handle dynamic growth.
    - Adjust padding and corner radius to match modern AI chat client aesthetics.
    - Ensure the "Send" and "Stop" buttons are correctly aligned.
3. **Refinement**: 
    - Adjust `minHeight` and `maxHeight` constraints.
    - Ensure it fits in the bottom area without obscuring the chat history.
4. **Validation**:
    - Build and test on iOS/macOS simulators.
    - Verify accessibility labels.
5. **Reporting**:
    - Create `Documentation/Development/COMPOSER_REDESIGN_REPORT.md` summarizing the changes and acceptance criteria.
